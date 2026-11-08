//
//  LanguageDetector.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage
import Synchronization

/// The language a text is written in, read from the text itself (Natural Language, on the device).
/// Scripts set to Auto-detect use it. It detects written text only: there is no reliable way to
/// tell the language someone is speaking before recognizing it, so Voice Following never guesses
/// that.
///
/// Creators mix languages: a few English words or a whole English phrase in a script written in
/// Portuguese. The language of a text is the one most of its words are in, sentence by sentence,
/// never the one its first words (or its most confident short phrase) happen to be in.
nonisolated enum LanguageDetector {
    /// Fewest words before the count by sentence is trusted over the whole text read at once.
    static let weighingMinimumWords = 8
    /// How sure the recognizer must be that a short phrase is in another language to call it one.
    static let foreignConfidence = 0.75
    /// How much of a text's weight the creator's languages add, and how close a second language
    /// must be to win by it: enough to settle text that could be either, far from enough to outvote clear text.
    static let leanWeight = 0.15

    /// ISO 639 code of the dominant language ("pt", "ja"), or nil when there's nothing to tell by.
    /// Cues aren't spoken, so they don't count. `preferring` (the creator's languages, such as the
    /// iPhone's) is a weak lean for text that could be either, never a vote against clear text.
    static func dominantLanguageCode(in text: String, preferring preferred: [String] = []) -> String? {
        dominantLanguage(in: text, preferring: preferred)?.languageCode?.identifier
    }

    /// The dominant language as Natural Language reads it, keeping the writing system when the
    /// language has two ("zh-Hant" for Traditional characters, "zh-Hans" for Simplified): reduced to
    /// "zh" a Traditional script would be heard, written and translated as Simplified.
    static func dominantLanguage(in text: String, preferring preferred: [String] = []) -> Locale.Language? {
        let key = preferred.joined(separator: ",") + "\u{1F}" + text
        if let known = dominantKept.withLock({ $0[key] }) { return known }
        let language = readDominantLanguage(in: text, preferring: preferred)
        dominantKept.withLock { kept in
            if kept.count >= keptLimit { kept.removeAll() }
            kept[key] = language
        }
        return language
    }

    /// What each text read as, kept: a text on the editor's preview asks for its direction every time it is drawn, and a script's row
    /// for its pace every time the list is, while the words stay the same (`keptLimit` texts, then it starts again).
    private static let dominantKept = Mutex<[String: Locale.Language?]>([:])
    private static let quickKept = Mutex<[String: CueLanguage?]>([:])
    static let keptLimit = 256

    private static func readDominantLanguage(in text: String, preferring preferred: [String]) -> Locale.Language? {
        let spoken = CueParser.stripCues(text)
        guard spoken.contains(where: { $0.isLetter }) else { return nil }
        let lean = lean(for: preferred)
        let whole = NLLanguageRecognizer()
        whole.processString(spoken)
        let wholeLanguage = whole.languageHypotheses(withMaximum: 2).sorted { $0.value > $1.value }
            .map(\.key).first { $0 != .undetermined }
        let language = weighed(spoken, lean: lean, fallback: wholeLanguage) ?? leaning(whole, to: lean) ?? wholeLanguage
        return language.map { Locale.Language(identifier: $0.rawValue) }
    }

    /// The detected language when Cue offers it, in the writing system the text uses.
    static func language(in text: String, preferring preferred: [String] = []) -> CueLanguage? {
        dominantLanguage(in: text, preferring: preferred).flatMap(CueLanguage.matching(language:))
    }

    /// The language of a text read at once from its first 600 characters, for what only needs the language roughly and asks often: how long a
    /// script runs at its language's pace (`ReadTime.pace(for:)`), in every row of the list. Nil for a text too short to tell by (three words).
    static func quickLanguage(in text: String) -> CueLanguage? {
        let start = String(text.prefix(700))
        if let known = quickKept.withLock({ $0[start] }) { return known }
        let spoken = String(CueParser.stripCues(start).prefix(600))
        var found: CueLanguage?
        if WordSegmenter.roughWordCount(of: spoken) >= 3 {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(spoken)
            if let language = recognizer.dominantLanguage, language != .undetermined {
                found = CueLanguage.matching(language: Locale.Language(identifier: language.rawValue))
            }
        }
        quickKept.withLock { kept in
            if kept.count >= keptLimit { kept.removeAll() }
            kept[start] = found
        }
        return found
    }

    /// Whether `words`, a short stretch of a text written in `code`, are clearly in another
    /// language: an English phrase in a Portuguese script. Needs two words and some letters, since
    /// a lone word says nothing about its language.
    static func isForeign(_ words: [String], to code: String) -> Bool {
        let phrase = words.joined(separator: " ")
        guard words.count >= 2, phrase.filter(\.isLetter).count >= 8 else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(phrase)
        guard let top = recognizer.languageHypotheses(withMaximum: 1).first,
              top.key != .undetermined, top.value >= foreignConfidence,
              let found = Locale.Language(identifier: top.key.rawValue).languageCode?.identifier else { return false }
        return found != code
    }

    // MARK: - By sentence

    /// The language most of the words are in, each sentence counting for its words: nil when the
    /// text is too short for that to mean more than reading it whole.
    private static func weighed(_ text: String, lean: Set<NLLanguage>, fallback: NLLanguage?) -> NLLanguage? {
        var total = 0.0
        var weights: [NLLanguage: Double] = [:]
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            let count = Double(WordSegmenter.roughWordCount(of: sentence))
            guard count > 0 else { return true }
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(sentence)
            total += count
            for (language, probability) in recognizer.languageHypotheses(withMaximum: 2) where language != .undetermined {
                weights[language, default: 0] += probability * count
            }
            return true
        }
        guard total >= Double(weighingMinimumWords) else { return nil }
        for language in lean where weights[language] != nil {
            weights[language, default: 0] += total * leanWeight
        }
        return weights.max { $0.value < $1.value }?.key ?? fallback
    }

    /// The creator's languages as a lean. It is added to the read of the text, never fed to the
    /// recognizer as a prior: `NLLanguageRecognizer.languageHints` replaces what the text says (an
    /// English-only hint reads a clear Portuguese text as English), and an iPhone set to English
    /// belongs to many creators who write in another language.
    private static func lean(for preferred: [String]) -> Set<NLLanguage> {
        Set(preferred.compactMap { identifier -> NLLanguage? in
            let language = Locale.Language(identifier: identifier)
            guard let code = language.languageCode?.identifier else { return nil }
            // Natural Language tells the two Chinese writing systems apart, so the lean has to name one.
            guard code == "zh" else { return NLLanguage(rawValue: code) }
            return NLLanguage(rawValue: CueLanguage.matching(language: language)?.chineseScriptIdentifier ?? "zh-Hans")
        })
    }

    /// For a text too short to weigh by sentence: the leaning language when it is a close second
    /// to the text's own, so a lean can settle a tie and nothing more.
    private static func leaning(_ recognizer: NLLanguageRecognizer, to lean: Set<NLLanguage>) -> NLLanguage? {
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2).sorted { $0.value > $1.value }
        guard let top = hypotheses.first, let second = hypotheses.dropFirst().first,
              lean.contains(second.key), top.value - second.value < leanWeight else { return nil }
        return second.key
    }
}
