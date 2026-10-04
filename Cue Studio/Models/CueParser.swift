//
//  CueParser.swift
//  Cue Studio
//

import Foundation

/// Parses the script text format: paragraphs separated by line breaks, stage cues in square
/// brackets (`[pause]`, `[smile]`, `[look at camera]`).
nonisolated enum CueParser {
    /// Non-empty paragraphs, trimmed.
    static func paragraphs(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func segments(in paragraph: String) -> [CueSegment] {
        var result: [CueSegment] = []
        var cursor = paragraph.startIndex
        for match in paragraph.matches(of: /\[[^\]]*\]/) {
            if cursor < match.range.lowerBound {
                result.append(CueSegment(kind: .speech, text: String(paragraph[cursor..<match.range.lowerBound])))
            }
            let inner = paragraph[match.range].dropFirst().dropLast()
            let cue = inner.trimmingCharacters(in: .whitespaces)
            if !cue.isEmpty {
                result.append(CueSegment(kind: .cue, text: cue))
            }
            cursor = match.range.upperBound
        }
        if cursor < paragraph.endIndex {
            result.append(CueSegment(kind: .speech, text: String(paragraph[cursor...])))
        }
        return result
    }

    /// How many stage cues the text has (`[pause]`, `[smile]`…): the "4 CUES" of a script's row and strip. An empty
    /// pair of brackets isn't one.
    static func count(in text: String) -> Int {
        text.matches(of: /\[[^\]]*\]/).filter { match in
            !text[match.range].dropFirst().dropLast().trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    /// The text without cues, with the spaces around removed cues collapsed.
    static func stripCues(_ text: String) -> String {
        text.replacing(/[ \t]*\[[^\]]*\][ \t]*/, with: " ")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }
}
