//
//  WordAlignment.swift
//  Cue Studio
//

import Foundation

/// Lines up two lists of words (what was heard and what was written, or a caption before and
/// after a correction): the longest run of words they share in the same order.
nonisolated enum WordAlignment {
    /// Words aligned at a time, to keep the work small on long takes.
    static let window = 300

    /// A word of the first list and the word of the second it lines up with.
    struct Match: Equatable, Sendable {
        let first: Int
        let second: Int
    }

    /// The longest common run of `first` and `second` (compared by `key`), found window by window
    /// so a long take stays quick. The second list gets a wider window: it may run ahead (a
    /// skipped line in the script).
    static func matches(_ first: [String], _ second: [String]) -> [Match] {
        var result: [Match] = []
        var firstFrom = 0
        var secondFrom = 0
        while firstFrom < first.count, secondFrom < second.count {
            let firstEnd = min(first.count, firstFrom + window)
            let secondEnd = min(second.count, secondFrom + window * 2)
            let found = longestCommon(Array(first[firstFrom..<firstEnd]), Array(second[secondFrom..<secondEnd]))
                .map { Match(first: $0.first + firstFrom, second: $0.second + secondFrom) }
            result += found
            if let last = found.last { secondFrom = last.second + 1 }
            firstFrom = firstEnd
        }
        return result
    }

    /// Shortest word that lines up reliably on its own.
    static let reliableLength = 5

    /// Matches that are part of a run of two or more, next to each other in both lists, or a word
    /// long enough not to line up by chance (`keys` are the first list's). A lone short word ("the",
    /// "e", "de") could be a common word matching somewhere else.
    static func reliable(_ matches: [Match], keys: [String] = []) -> [Match] {
        matches.enumerated().filter { index, match in
            if keys.indices.contains(match.first), keys[match.first].count >= reliableLength { return true }
            let before = index > 0 ? matches[index - 1] : nil
            let after = index + 1 < matches.count ? matches[index + 1] : nil
            let followsBefore = before.map { $0.first == match.first - 1 && $0.second == match.second - 1 } ?? false
            let leadsAfter = after.map { $0.first == match.first + 1 && $0.second == match.second + 1 } ?? false
            return followsBefore || leadsAfter
        }
        .map(\.element)
    }

    /// A word as compared: lowercased, without accents or punctuation, folded like Voice
    /// Following's words (`WordTokenizer.key`). Empty for punctuation alone, which never matches.
    static func key(_ word: String) -> String {
        WordTokenizer.key(word)
    }

    private static func longestCommon(_ first: [String], _ second: [String]) -> [Match] {
        let rows = first.count
        let columns = second.count
        guard rows > 0, columns > 0 else { return [] }
        // lengths[i][j]: the longest common run of first[i...] and second[j...].
        var lengths = [[UInt16]](repeating: [UInt16](repeating: 0, count: columns + 1), count: rows + 1)
        for i in stride(from: rows - 1, through: 0, by: -1) {
            for j in stride(from: columns - 1, through: 0, by: -1) {
                lengths[i][j] = !first[i].isEmpty && first[i] == second[j]
                    ? lengths[i + 1][j + 1] + 1
                    : max(lengths[i + 1][j], lengths[i][j + 1])
            }
        }
        var result: [Match] = []
        var i = 0
        var j = 0
        while i < rows, j < columns {
            if !first[i].isEmpty, first[i] == second[j] {
                result.append(Match(first: i, second: j))
                i += 1
                j += 1
            } else if lengths[i + 1][j] >= lengths[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return result
    }
}
