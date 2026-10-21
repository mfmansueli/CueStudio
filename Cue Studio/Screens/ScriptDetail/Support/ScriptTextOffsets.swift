//
//  ScriptTextOffsets.swift
//  Cue Studio
//

import Foundation

/// The page counts its text in characters (what the creator sees: an emoji is one); a text view counts it in UTF-16 units
/// (`NSRange`). These turn one into the other, clamped to the text, so an emoji or an accent never puts the caret a few letters off.
nonisolated enum ScriptTextOffsets {
    static func nsRange(of characters: Range<Int>, in text: String) -> NSRange {
        let count = text.count
        let lower = min(max(0, characters.lowerBound), count)
        let upper = min(max(lower, characters.upperBound), count)
        let start = text.index(text.startIndex, offsetBy: lower)
        return NSRange(start..<text.index(start, offsetBy: upper - lower), in: text)
    }

    static func characters(of range: NSRange, in text: String) -> Range<Int>? {
        guard let bounds = Range(range, in: text) else { return nil }
        let lower = text.distance(from: text.startIndex, to: bounds.lowerBound)
        return lower..<(lower + text.distance(from: bounds.lowerBound, to: bounds.upperBound))
    }

    /// What changed between `old` and `new`, in characters: the part of `old` that goes and the part of `new` that takes its place
    /// (the same start). Equal texts give two empty ranges.
    static func change(from old: String, to new: String) -> (removed: Range<Int>, inserted: Range<Int>) {
        let before = Array(old)
        let after = Array(new)
        var prefix = 0
        while prefix < before.count, prefix < after.count, before[prefix] == after[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < before.count - prefix, suffix < after.count - prefix,
              before[before.count - 1 - suffix] == after[after.count - 1 - suffix] {
            suffix += 1
        }
        return (prefix..<(before.count - suffix), prefix..<(after.count - suffix))
    }
}
