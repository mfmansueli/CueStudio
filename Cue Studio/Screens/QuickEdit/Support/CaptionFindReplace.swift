//
//  CaptionFindReplace.swift
//  Cue Studio
//

import Foundation

/// Find and replace in the caption lines: a word (or any run of letters) is found in every line, ignoring capitals and
/// full/half width ("cue" finds "Cue"), never accents ("e" never finds "é": in many languages they are different words).
/// Matches never overlap and are counted left to right, so the third match of a line is always the same one. Only the
/// text changes: the line keeps its times, and its words keep the voice's times where they still match
/// (`CaptionRevision.retimed`).
nonisolated enum CaptionFindReplace {
    /// The longest a search can be: a caption line is a few words.
    static let maximumQueryLength = 80

    private static let options: String.CompareOptions = [.caseInsensitive, .widthInsensitive]

    /// The query as searched: its spaces at the ends dropped; empty finds nothing.
    static func cleaned(_ query: String) -> String {
        String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumQueryLength))
    }

    /// Where `query` is in `text`, left to right, without overlapping.
    static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        let query = cleaned(query)
        guard !query.isEmpty else { return [] }
        var found: [Range<String.Index>] = []
        var searched = text.startIndex..<text.endIndex
        while let range = text.range(of: query, options: options, range: searched), !range.isEmpty {
            found.append(range)
            searched = range.upperBound..<text.endIndex
        }
        return found
    }

    /// How many times `query` is in `text`.
    static func count(of query: String, in text: String) -> Int {
        ranges(of: query, in: text).count
    }

    /// `text` with the `occurrence`-th match of `query` (from 0) replaced, or every match when `occurrence` is nil. The
    /// text as it was when there is no such match. Spaces doubled by the replacement (an emptied word) are folded.
    static func replacing(_ query: String, with replacement: String, in text: String, occurrence: Int? = nil) -> String {
        let ranges = ranges(of: query, in: text)
        let chosen: [Range<String.Index>]
        if let occurrence {
            guard ranges.indices.contains(occurrence) else { return text }
            chosen = [ranges[occurrence]]
        } else {
            chosen = ranges
        }
        guard !chosen.isEmpty else { return text }
        var result = text
        // From the end, so the ranges before stay valid.
        for range in chosen.reversed() {
            result.replaceSubrange(range, with: replacement)
        }
        return replacement.isEmpty ? folded(result) : result
    }

    /// One match in the lines, as the list shows it: the line, which of its matches, and the words around it.
    struct Match: Hashable, Identifiable {
        let cueID: UUID
        /// Which match of the line, from 0.
        let occurrence: Int
        /// The line's text before the match, the match itself and the text after it.
        let before: String
        let found: String
        let after: String

        var id: String { "\(cueID.uuidString)-\(occurrence)" }
    }

    /// Every match of `query` in `lines`, in their order.
    static func matches(of query: String, in lines: [CaptionCue]) -> [Match] {
        lines.flatMap { line in
            ranges(of: query, in: line.text).enumerated().map { index, range in
                Match(
                    cueID: line.id, occurrence: index, before: String(line.text[..<range.lowerBound]),
                    found: String(line.text[range]), after: String(line.text[range.upperBound...])
                )
            }
        }
    }

    /// Double spaces left where a word was replaced by nothing, and spaces at the ends.
    private static func folded(_ text: String) -> String {
        var result = text
        while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
