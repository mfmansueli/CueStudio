//
//  VoiceRunMetrics.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// How the scripts of a device run (`VoiceRunSample`) hold up against the creator they were written for (plan §6): the hard constraints, how
/// well they follow the profile, and how different two creators' scripts are for the same idea. Judged by what the personas say
/// (`VoicePersona.forbiddenTerms`, `topicTerms`, their pronoun), written by hand, and by the same checker the app runs after a script.
/// Whether a script *sounds like* the creator is not here: that is for people (the blind pairs).
nonisolated struct VoiceRunMetrics: Sendable {
    /// What was counted for the scripts of one condition ("no-voice", "voice") of one run.
    struct Summary: Sendable {
        var scripts = 0
        /// Scripts that came back with words (the rest failed).
        var written = 0
        var avoided = 0
        var pronoun = 0
        var catchphraseFirst = 0
        var styleName = 0
        var emoji = 0
        var tooShort = 0
        var wrongLanguage = 0
        var totalWords = 0
        var topicHits = 0
        var sentenceFits = 0
        var sentenceJudged = 0
        var openingFollowed = 0
        var openingJudged = 0

        /// Scripts that broke at least one hard constraint the creator asked for (avoid, "I" or "we", a catchphrase or a style's name as the opening).
        var hard: Int { avoided + pronoun + catchphraseFirst + styleName + emoji }
        var averageWords: Double { written == 0 ? 0 : Double(totalWords) / Double(written) }
        var topicRate: Double { written == 0 ? 0 : Double(topicHits) / Double(written) }
        var sentenceRate: Double { sentenceJudged == 0 ? 0 : Double(sentenceFits) / Double(sentenceJudged) }
        var openingRate: Double { openingJudged == 0 ? 0 : Double(openingFollowed) / Double(openingJudged) }
    }

    /// The summary of each condition, by name.
    let byCondition: [String: Summary]

    @MainActor
    init(_ samples: [VoiceRunSample]) {
        var result: [String: Summary] = [:]
        for sample in samples {
            var summary = result[sample.condition] ?? Summary()
            Self.count(sample, into: &summary)
            result[sample.condition] = summary
        }
        byCondition = result
    }

    // MARK: - One script

    @MainActor
    private static func count(_ sample: VoiceRunSample, into summary: inout Summary) {
        summary.scripts += 1
        guard let text = sample.text, !text.isEmpty, let persona = VoicePersonas.persona(sample.persona) else { return }
        summary.written += 1
        let spoken = CueParser.stripCues(text)
        let words = ReadTime.wordCount(in: spoken)
        summary.totalWords += words
        let lowered = spoken.lowercased().replacingOccurrences(of: "’", with: "'")
        // What the persona says must not be there, as the persona's own list (not the app's).
        if persona.forbiddenTerms.contains(where: { lowered.contains($0.lowercased().replacingOccurrences(of: "’", with: "'")) }) { summary.avoided += 1 }
        if persona.topicTerms.contains(where: { lowered.contains($0.lowercased()) }) { summary.topicHits += 1 }
        // The rest by the checker the app runs, with the voice the persona holds (an "I" or a "we" of the persona's own, not the role's).
        var voice = persona.profile.voice
        voice.speaksAs = persona.pronoun == .we ? .we : .i
        let kinds = Set(VoiceConstraintChecker.violations(in: text, voice: voice, language: persona.language, minimumWords: 150).map(\.kind))
        if kinds.contains(.pronoun) { summary.pronoun += 1 }
        if kinds.contains(.catchphraseFirst) { summary.catchphraseFirst += 1 }
        if kinds.contains(.styleName) { summary.styleName += 1 }
        if kinds.contains(.emoji) { summary.emoji += 1 }
        if kinds.contains(.tooShort) { summary.tooShort += 1 }
        if !OutputLanguageCheck.isPlausible(text, in: persona.language) { summary.wrongLanguage += 1 }
        if let fits = sentenceFit(of: spoken, wanted: persona.profile.style.sentences) {
            summary.sentenceJudged += 1
            if fits { summary.sentenceFits += 1 }
        }
        if let followed = openingFollowed(by: spoken, openings: persona.profile.openings) {
            summary.openingJudged += 1
            if followed { summary.openingFollowed += 1 }
        }
    }

    // MARK: - Adherence

    /// Spoken words in a sentence, on average.
    static func averageSentenceLength(of spoken: String) -> Double {
        let sentences = spoken.split { ".?!\n".contains($0) }.map { ReadTime.wordCount(in: String($0)) }.filter { $0 > 0 }
        guard !sentences.isEmpty else { return 0 }
        return Double(sentences.reduce(0, +)) / Double(sentences.count)
    }

    /// Whether the sentences are as long as the creator said ("short" up to 12 words on average, "long" from 16, "mixed" between 8 and 20);
    /// nil when they said nothing.
    static func sentenceFit(of spoken: String, wanted: SentenceLength?) -> Bool? {
        guard let wanted else { return nil }
        let average = averageSentenceLength(of: spoken)
        return switch wanted {
        case .short: average <= 12
        case .mixed: (8...20).contains(average)
        case .long: average >= 16
        }
    }

    /// Whether the first sentence is the way the creator opens (a question ends with "?", a number has a digit or "POV" starts it); nil when
    /// they chose a way a count can't judge (a bold claim, a story).
    static func openingFollowed(by spoken: String, openings: [String]) -> Bool? {
        let text = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let terminator = text.first { ".?!".contains($0) }
        let first = text.prefix { !".?!\n".contains($0) }
        for stored in openings {
            guard case .known(let id, _) = VoiceChoiceCatalog.opening(stored) else { continue }
            switch id {
            case "Question": return terminator == "?"
            case "Start with a number": return first.contains { $0.isNumber }
            case "POV": return first.lowercased().hasPrefix("pov")
            default: continue
            }
        }
        return nil
    }

    // MARK: - Distinction

    /// How different the scripts of different creators are for the same idea, from 0 (the same words) to 1 (nothing in common): the mean of
    /// one minus the share of three-word runs two scripts have in common, over every pair of creators and every idea they both wrote.
    static func distinction(_ samples: [VoiceRunSample], condition: String) -> Double {
        let scripts = samples.filter { $0.condition == condition && $0.wasWritten }
        var distances: [Double] = []
        for index in Set(scripts.map(\.ideaIndex)) {
            let sets = scripts.filter { $0.ideaIndex == index }.map { trigrams(of: $0.text ?? "") }
            for i in sets.indices {
                for j in sets.indices where j > i {
                    let union = sets[i].union(sets[j]).count
                    guard union > 0 else { continue }
                    distances.append(1 - Double(sets[i].intersection(sets[j]).count) / Double(union))
                }
            }
        }
        return distances.isEmpty ? 0 : distances.reduce(0, +) / Double(distances.count)
    }

    static func trigrams(of text: String) -> Set<String> {
        let words = CueParser.stripCues(text).lowercased().split { !($0.isLetter || $0.isNumber || $0 == "'") }.map(String.init)
        guard words.count >= 3 else { return [] }
        return Set((0...(words.count - 3)).map { words[$0...($0 + 2)].joined(separator: " ") })
    }
}
