//
//  CoverWords.swift
//  Cue Studio
//

import Foundation

/// The words of a cover's title, found the way the system breaks words in any language (by spaces, or by dictionary in
/// Japanese, Chinese and Thai), so a highlight is always a whole word and never part of one. Pure, so the panel's word chips,
/// the renderer and the tests see the same words.
nonisolated enum CoverWords {
    /// Each word's range in `text`, in order.
    static func ranges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) { _, range, _, _ in
            ranges.append(range)
        }
        return ranges
    }

    static func words(in text: String) -> [String] {
        ranges(in: text).map { String(text[$0]) }
    }

    /// The word a new cover highlights: the longest that isn't a number (the first of them on a tie), when the title has more
    /// than one word.
    static func keyWord(in text: String) -> Int? {
        let words = words(in: text)
        guard words.count > 1 else { return nil }
        let candidates = words.indices.filter { !words[$0].allSatisfy(\.isNumber) }
        return candidates.max { words[$0].count < words[$1].count || (words[$0].count == words[$1].count && $0 > $1) }
    }

    /// The title's first number ("5" of "5 foods in São Paulo"), for a list cover; nil without one.
    static func firstNumber(in text: String) -> String? {
        words(in: text).first { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }
}
