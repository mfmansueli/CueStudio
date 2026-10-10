//
//  DraftEdits.swift
//  Cue Studio
//

import Foundation

/// How much of a script the creator made their own: the spoken words of Cue's draft against the version they recorded, word by word
/// (cues, case and punctuation aside). A script counts as theirs to learn from when at least a fifth of its words is new or moved and at
/// least `minimumChangedWords` changed: a fixed typo or a swapped word isn't their voice yet. Pure, so every case is tested without the
/// app.
nonisolated enum DraftEdits {
    /// The share of words that changed, from which a recorded script is learned from.
    static let learningShare = 0.2
    /// And at least this many words.
    static let minimumChangedWords = 8
    /// Scripts longer than this compare their first part only: the voice shows as well there, and the comparison stays quick.
    static let comparedWords = 600

    /// How many words of `final` aren't Cue's, in Cue's order (the longest run they share left out), and how many it has.
    static func changed(from draft: String, to final: String) -> (changed: Int, total: Int) {
        let before = words(in: draft)
        let after = words(in: final)
        guard !after.isEmpty else { return (0, 0) }
        let kept = commonLength(before, after)
        return (max(before.count, after.count) - kept, max(before.count, after.count))
    }

    /// The recorded script is the creator's enough to learn from.
    static func isTheirs(draft: String, final: String) -> Bool {
        let (changed, total) = changed(from: draft, to: final)
        guard total > 0 else { return false }
        return changed >= minimumChangedWords && Double(changed) / Double(total) >= learningShare
    }

    /// Spoken words only, folded (case, accents) and without the punctuation around them.
    static func words(in text: String) -> [String] {
        let spoken = CueParser.stripCues(text).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let words = spoken.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map { $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols)) }
            .filter { !$0.isEmpty }
        return Array(words.prefix(comparedWords))
    }

    /// The longest sequence of words both have in the same order (two rows of the table at a time).
    static func commonLength(_ lhs: [String], _ rhs: [String]) -> Int {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: rhs.count + 1)
        var current = previous
        for word in lhs {
            for (index, other) in rhs.enumerated() {
                current[index + 1] = word == other ? previous[index] + 1 : max(previous[index + 1], current[index])
            }
            swap(&previous, &current)
        }
        return previous[rhs.count]
    }
}
