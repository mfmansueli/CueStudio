//
//  AIPassage.swift
//  Cue Studio
//

import Foundation

/// What the AI wrote in place of a selection, while it waits for ✓ Keep, ↺ Undo or ✦ Try again (v29 · A): the words it
/// replaced, the new ones and where they sit in the text, in characters from its start. The new words show in violet until
/// the creator keeps them (tapping outside keeps them).
nonisolated struct AIPassage: Equatable, Sendable {
    let action: SelectionAction
    let original: String
    var replacement: String
    /// Where `replacement` sits.
    var range: Range<Int>

    /// The text with the old words back in place of the new ones; the text as it is when they are no longer where
    /// they were (the creator typed on).
    func undone(in text: String) -> String {
        guard let span = location(in: text) else { return text }
        return text.replacingCharacters(in: span, with: original)
    }

    private func location(in text: String) -> Range<String.Index>? {
        let characters = text.count
        if range.upperBound <= characters,
           let lower = text.index(text.startIndex, offsetBy: range.lowerBound, limitedBy: text.endIndex),
           let upper = text.index(text.startIndex, offsetBy: range.upperBound, limitedBy: text.endIndex),
           text[lower..<upper] == replacement {
            return lower..<upper
        }
        return text.range(of: replacement)
    }
}
