//
//  FillerWordDetector.swift
//  Cue Studio
//

import Foundation

/// Finds filler words ("um", "uh", "tipo", "you know") in the transcript of a take, from its word
/// timings. Suggestions only: "like" can mean something and "Ah!" can be the point, so words that
/// are filler only sometimes count only when the speaker hesitates around them, never when said
/// as an exclamation, and with a lower confidence. The creator decides what goes. Pure, so it is
/// tested with made-up words.
nonisolated enum FillerWordDetector {
    /// A gap at least this long next to a word means the speaker hesitated.
    static let hesitation: TimeInterval = 0.25
    static let soundConfidence = 0.9
    static let phraseConfidence = 0.5

    /// Sounds that are filler wherever they come, by language code, in spoken form (see
    /// `TimedWord.spoken`: held sounds are cut to two letters).
    static let sounds: [String: Set<String>] = [
        "en": ["um", "umm", "uh", "uhh", "uhm", "er", "erm", "hm", "hmm", "mm"],
        "pt": ["éé", "hã", "ãh", "ahn", "hum", "hm", "hmm", "mm"],
        "es": ["eh", "ehh", "em", "emm", "hm", "hmm", "mm"],
    ]

    /// Words and phrases that are filler only sometimes, by language code.
    static let phrases: [String: [[String]]] = [
        "en": [["you", "know"], ["i", "mean"], ["like"], ["basically"], ["literally"], ["so"], ["ah"]],
        "pt": [["tipo"], ["né"], ["então"], ["assim"], ["sabe"], ["é"], ["ah"]],
        "es": [["o", "sea"], ["este"], ["pues"], ["bueno"], ["ah"]],
    ]

    /// Fillers in `words` (in the order said), for the language with `languageCode` ("en", "pt",
    /// "es"). None for a language it doesn't know.
    static func suggestions(in words: [TimedWord], languageCode: String) -> [CleanUpSuggestion] {
        let fillerSounds = Self.sounds[languageCode] ?? []
        // Longer phrases first, so "you know" wins over a shorter match at the same word.
        let fillerPhrases = (Self.phrases[languageCode] ?? []).sorted { $0.count > $1.count }
        let spoken = words.map(\.spoken)
        var result: [CleanUpSuggestion] = []
        var index = 0
        while index < words.count {
            if fillerSounds.contains(spoken[index]) {
                result.append(suggestion(words, from: index, through: index, confidence: soundConfidence))
                index += 1
            } else if let phrase = fillerPhrases.first(where: { TimedWord.phrase($0, isSaidIn: spoken, at: index) }),
                      isHesitant(words, from: index, through: index + phrase.count - 1) {
                result.append(suggestion(words, from: index, through: index + phrase.count - 1, confidence: phraseConfidence))
                index += phrase.count
            } else {
                index += 1
            }
        }
        return result
    }

    /// Said with a pause before or after it, and not as an exclamation or a question.
    private static func isHesitant(_ words: [TimedWord], from first: Int, through last: Int) -> Bool {
        guard !words[last].isEmphatic else { return false }
        let pauseBefore = first > 0 && words[first].start - words[first - 1].end >= hesitation
        let pauseAfter = last + 1 < words.count && words[last + 1].start - words[last].end >= hesitation
        return pauseBefore || pauseAfter
    }

    private static func suggestion(_ words: [TimedWord], from first: Int, through last: Int, confidence: Double) -> CleanUpSuggestion {
        CleanUpSuggestion(
            kind: .filler,
            span: TimeSpan(start: words[first].start, end: words[last].end),
            text: TimedWord.text(of: words, from: first, through: last),
            confidence: confidence
        )
    }
}
