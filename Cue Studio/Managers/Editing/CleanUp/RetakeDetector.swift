//
//  RetakeDetector.swift
//  Cue Studio
//

import Foundation

/// Finds where the speaker started over, from the transcript of a take with its word timings:
/// a phrase that says so ("let me start again", "deixa eu falar de novo") takes back what was said
/// since the last pause before it, and words said twice in a row ("today I want, today I want to
/// talk") drop the first try. Suggestions only: "wait" can be part of the script, so short phrases
/// get a lower confidence and the creator decides. Pure, so it is tested with made-up words.
nonisolated enum RetakeDetector {
    /// A pause at least this long separates two attempts.
    static let attemptGap: TimeInterval = 0.6
    /// The furthest back a restart phrase takes an attempt back.
    static let maximumTakeBack: TimeInterval = 12
    /// Words repeated in a row count as a false start from this many (a single "really really"
    /// is usually on purpose) up to `longestRepeat`.
    static let shortestRepeat = 2
    static let longestRepeat = 8
    static let phraseConfidence = 0.7
    static let shortPhraseConfidence = 0.4
    static let repeatConfidence = 0.7

    /// Phrases that announce a restart, by language code, in spoken form.
    static let restartPhrases: [String: [[String]]] = [
        "en": [
            ["let", "me", "start", "again"], ["let", "me", "start", "over"], ["let", "me", "try", "that", "again"],
            ["let", "me", "try", "again"], ["let", "me", "say", "that", "again"], ["start", "over"],
            ["from", "the", "top"], ["i", "messed", "up"], ["wait"], ["sorry"],
        ],
        "pt": [
            ["deixa", "eu", "falar", "de", "novo"], ["deixa", "eu", "começar", "de", "novo"],
            ["vamos", "começar", "de", "novo"], ["vou", "começar", "de", "novo"], ["começar", "de", "novo"],
            ["vou", "falar", "de", "novo"], ["espera"], ["errei"], ["peraí"],
        ],
        "es": [
            ["empiezo", "de", "nuevo"], ["vuelvo", "a", "empezar"], ["otra", "vez"], ["espera"], ["me", "equivoqué"],
        ],
    ]

    /// Possible retakes in `words` (in the order said), for the language with `languageCode`.
    /// Repeated words are found in any language; restart phrases only in the ones it knows.
    static func suggestions(in words: [TimedWord], languageCode: String) -> [CleanUpSuggestion] {
        let spoken = words.map(\.spoken)
        let phrases = (Self.restartPhrases[languageCode] ?? []).sorted { $0.count > $1.count }
        var result: [CleanUpSuggestion] = []
        var index = 0
        while index < words.count {
            if let phrase = phrases.first(where: { TimedWord.phrase($0, isSaidIn: spoken, at: index) }) {
                let last = index + phrase.count - 1
                let first = attemptStart(before: index, in: words)
                let span = TimeSpan(start: words[first].start, end: words[last].end)
                // The attempt taken back already covers anything found inside it.
                result.removeAll { $0.span.end > span.start }
                result.append(CleanUpSuggestion(
                    kind: .retake, span: span, text: TimedWord.text(of: words, from: first, through: last),
                    confidence: phrase.count >= 3 ? phraseConfidence : shortPhraseConfidence
                ))
                index = last + 1
            } else if let length = repeatLength(at: index, in: spoken) {
                // The first try goes, up to where the second begins.
                result.append(CleanUpSuggestion(
                    kind: .retake,
                    span: TimeSpan(start: words[index].start, end: words[index + length].start),
                    text: TimedWord.text(of: words, from: index, through: index + length - 1),
                    confidence: repeatConfidence
                ))
                index += length
            } else {
                index += 1
            }
        }
        return result
    }

    /// Where the attempt taken back by a restart phrase at `index` began: the first word after the
    /// last long pause before it, no further back than `maximumTakeBack`.
    private static func attemptStart(before index: Int, in words: [TimedWord]) -> Int {
        var first = index
        while first > 0,
              words[first].start - words[first - 1].end < attemptGap,
              words[index].start - words[first - 1].start <= maximumTakeBack {
            first -= 1
        }
        return first
    }

    /// How many words starting at `index` are said again right after, longest first.
    private static func repeatLength(at index: Int, in spoken: [String]) -> Int? {
        let longest = min(longestRepeat, (spoken.count - index) / 2)
        guard longest >= shortestRepeat, !spoken[index].isEmpty else { return nil }
        return (shortestRepeat...longest).reversed().first { length in
            spoken[index..<index + length].elementsEqual(spoken[index + length..<index + 2 * length])
        }
    }
}
