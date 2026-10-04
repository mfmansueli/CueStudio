//
//  ScriptCueShaper.swift
//  Cue Studio
//

import Foundation

/// "✦ Shape" (v29 · L2): a script with no cues gets up to four where they help the delivery: a pause after the hook, a
/// stress on the first line of the middle, a look at the camera before the closing and a smile at its end. Only adds
/// cues: the words never change, and it never touches a script that has cues already.
nonisolated enum ScriptCueShaper {
    struct Result: Equatable, Sendable {
        let text: String
        let added: Int
    }

    static func shaped(_ text: String) -> Result {
        guard CueParser.count(in: text) == 0 else { return Result(text: text, added: 0) }
        var paragraphs = text.components(separatedBy: "\n")
        let filled = paragraphs.indices.filter { !paragraphs[$0].trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = filled.first else { return Result(text: text, added: 0) }
        var added = 0

        func append(_ cue: ScriptCue, toSentence sentence: Int, of index: Int, after: Bool = true) {
            let line = paragraphs[index]
            let sentences = ScriptShape.sentences(in: line)
            guard sentence < sentences.count, let range = line.range(of: sentences[sentence]) else { return }
            let tag = "[\(cue.name)]"
            paragraphs[index] = after
                ? line.replacingCharacters(in: range, with: sentences[sentence] + " " + tag)
                : line.replacingCharacters(in: range, with: tag + " " + sentences[sentence])
            added += 1
        }

        // The hook: a pause so it lands.
        append(.pause, toSentence: 0, of: first)
        if filled.count >= 3 {
            // The middle: its first line is the point.
            append(.emphasis, toSentence: 0, of: filled[filled.count / 2], after: false)
        }
        if filled.count >= 2, let last = filled.last {
            let sentences = ScriptShape.sentences(in: paragraphs[last])
            append(.lookAtCamera, toSentence: 0, of: last, after: false)
            if sentences.count > 1 { append(.smile, toSentence: sentences.count - 1, of: last) }
        }
        return Result(text: paragraphs.joined(separator: "\n"), added: added)
    }
}
