//
//  ScriptCueShaper.swift
//  Cue Studio
//

import Foundation

/// "✦ Shape" (v29 · L2): a script with no cues gets up to four where they help the delivery: a pause after the hook's first sentence, a
/// stress on the first line of the middle, a look at the camera before the closing and a smile at its end (never in a serious format: an
/// apology doesn't close on a smile). A script written in one block is shaped by its sentences. Only adds cues, named in the script's language:
/// the words never change, and it never touches a script that has cues already (a disclosure's cue isn't one). Rules only, no model: it is there
/// with or without Apple Intelligence.
nonisolated enum ScriptCueShaper {
    struct Result: Equatable, Sendable {
        let text: String
        let added: Int
    }

    /// The cues the creator or the model wrote, not counting the disclosure's (`ScriptTextEditing.disclosureCue`).
    static func cueCount(in text: String) -> Int {
        CueParser.count(in: text) - text.lowercased().components(separatedBy: ScriptTextEditing.disclosureCue).count + 1
    }

    static func shaped(_ text: String, language: CueLanguage? = nil, isSerious: Bool = false) -> Result {
        guard cueCount(in: text) == 0 else { return Result(text: text, added: 0) }
        let lines = lineRanges(in: text).filter { !ScriptTextEditing.isDisclosure(String(text[$0])) }
        guard let first = lines.first else { return Result(text: text, added: 0) }
        // Each insertion: where, and what. Applied from the end, so the places found first stay right.
        var insertions: [(at: String.Index, text: String)] = []
        func tag(_ cue: ScriptCue) -> String { "[\(cue.name(in: language))]" }

        let opening = sentenceRanges(in: text, line: first)
        if let hook = opening.first { insertions.append((hook.upperBound, " " + tag(.pause))) }
        // The units the middle and the closing are found in: the paragraphs, or the sentences of a script written in one block.
        let units = lines.count > 1 ? lines : Array(opening.dropFirst())
        if units.count >= 3 {
            insertions.append((units[units.count / 2].lowerBound, tag(.emphasis) + " "))
        }
        if lines.count > 1 || units.count >= 2, let last = units.last {
            insertions.append((last.lowerBound, tag(.lookAtCamera) + " "))
            let closing = lines.count > 1 ? sentenceRanges(in: text, line: last) : [last]
            if !isSerious, lines.count == 1 || closing.count > 1, let end = closing.last?.upperBound {
                insertions.append((end, " " + tag(.smile)))
            }
        }
        var shaped = text
        for insertion in insertions.sorted(by: { $0.at > $1.at }) {
            shaped.insert(contentsOf: insertion.text, at: insertion.at)
        }
        return Result(text: shaped, added: insertions.count)
    }

    /// The lines with words, each without the spaces at its ends.
    private static func lineRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text[start...].firstIndex(of: "\n") ?? text.endIndex
            if let trimmed = trimmed(start..<end, in: text) { ranges.append(trimmed) }
            start = end < text.endIndex ? text.index(after: end) : end
        }
        return ranges
    }

    /// The sentences of one line, each without the spaces after it.
    private static func sentenceRanges(in text: String, line: Range<String.Index>) -> [Range<String.Index>] {
        var start = line.lowerBound
        return ScriptParagraphs.sentences(of: String(text[line])).compactMap { sentence in
            let end = text.index(start, offsetBy: sentence.count, limitedBy: line.upperBound) ?? line.upperBound
            defer { start = end }
            return trimmed(start..<end, in: text)
        }
    }

    private static func trimmed(_ range: Range<String.Index>, in text: String) -> Range<String.Index>? {
        guard let lower = text[range].firstIndex(where: { !$0.isWhitespace }),
              let last = text[range].lastIndex(where: { !$0.isWhitespace }) else { return nil }
        return lower..<text.index(after: last)
    }
}
