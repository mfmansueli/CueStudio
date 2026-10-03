//
//  DictationSegment.swift
//  Cue Studio
//

import Foundation

/// The part of the idea a dictation is writing. When dictation starts, the text is split at the
/// insertion point into what comes `before` and what comes `after`; every transcript, partial or
/// final, then replaces only what sits between them. So words heard twice never repeat, and nothing
/// the creator had written is overwritten, moved or lost.
nonisolated struct DictationSegment: Equatable, Sendable {
    let before: String
    let after: String
    /// The transcript so far, as the recognizer wrote it (it grows, and may rewrite its last words).
    private(set) var heard = ""

    /// - Parameter caret: character offset where the words go; nil (or past the end) is the end.
    init(in text: String, caret: Int?) {
        let offset = min(max(caret ?? text.count, 0), text.count)
        let split = text.index(text.startIndex, offsetBy: offset)
        before = String(text[..<split])
        after = String(text[split...])
    }

    mutating func hear(_ transcript: String) {
        heard = transcript
    }

    /// The whole text with the words in place, spaced from their neighbours.
    var text: String {
        let words = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return before + after }
        return before + Self.gap(between: before, and: words) + words + Self.gap(between: words, and: after) + after
    }

    /// Where the words end, as a character offset into `text`: where the caret goes when dictation stops.
    var endOffset: Int {
        let words = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return before.count }
        return before.count + Self.gap(between: before, and: words).count + words.count
    }

    var hasWords: Bool { !heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Spacing

    private static let closing: Set<Character> = [".", ",", ";", ":", "!", "?", "…", ")", "]", "}", "»", "”", "’", "。", "、", "！", "？", "，"]

    /// A space where two pieces of text would otherwise run together: none after whitespace or
    /// before closing punctuation, and none between letters of writing that has no spaces.
    private static func gap(between left: String, and right: String) -> String {
        guard let last = left.last, let first = right.first else { return "" }
        if last.isWhitespace || first.isWhitespace || closing.contains(first) { return "" }
        if WordSegmenter.containsUnspacedScript(String(last)) || WordSegmenter.containsUnspacedScript(String(first)) { return "" }
        return " "
    }
}
