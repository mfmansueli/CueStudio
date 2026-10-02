//
//  IdeaPromptDraft+Selection.swift
//  Cue Studio
//

import SwiftUI

extension IdeaPromptDraft {
    /// The character offset of the insertion point in `text`; nil when the field has none (it was
    /// never focused). A selected range counts from its end: dictation adds after it, never over it.
    static func caretOffset(of selection: TextSelection?, in text: String) -> Int? {
        guard let selection else { return nil }
        let end: String.Index?
        switch selection.indices {
        case .selection(let range): end = range.upperBound
        case .multiSelection(let ranges): end = ranges.ranges.last?.upperBound
        @unknown default: end = nil
        }
        guard let end, end <= text.endIndex else { return nil }
        return text.distance(from: text.startIndex, to: end)
    }

    /// A selection with the caret at `offset` characters into `text` (clamped to its end).
    static func selection(at offset: Int, in text: String) -> TextSelection {
        TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: min(max(offset, 0), text.count)))
    }
}
