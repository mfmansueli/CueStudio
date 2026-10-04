//
//  RewriteCandidate.swift
//  Cue Studio
//

import Foundation

/// What the AI wrote for a selection, held until the creator says "Use" or "Keep mine": the old
/// words struck through above the new ones.
nonisolated struct RewriteCandidate: Equatable, Sendable {
    let action: SelectionAction
    let original: String
    let rewritten: String
    /// Where the original sat, in characters from the start of the text.
    let offsets: Range<Int>

    /// The text with the new words in place of the old, or the text as it is when the old words are
    /// no longer where they were (the creator kept typing).
    func applied(to text: String) -> String {
        guard let range = location(in: text) else { return text }
        return text.replacingCharacters(in: range, with: rewritten)
    }

    private func location(in text: String) -> Range<String.Index>? {
        if let lower = text.index(text.startIndex, offsetBy: offsets.lowerBound, limitedBy: text.endIndex),
           let upper = text.index(text.startIndex, offsetBy: offsets.upperBound, limitedBy: text.endIndex),
           text[lower..<upper] == original {
            return lower..<upper
        }
        return text.range(of: original)
    }
}
