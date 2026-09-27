//
//  ScriptTextNormalizer.swift
//  Cue Studio
//

import Foundation

/// Cleans text coming from the clipboard or imported documents into the script format:
/// one paragraph per line block, blank lines between paragraphs.
nonisolated enum ScriptTextNormalizer {
    /// - Parameter joinWrappedLines: PDFs and some documents hard-wrap lines inside a paragraph.
    ///   When true, single line breaks are joined and only blank lines separate paragraphs.
    static func normalize(_ text: String, joinWrappedLines: Bool = false) -> String {
        let unified = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        let blocks = unified.split(separator: /\n[ \t]*\n+/, omittingEmptySubsequences: true).map(String.init)
        let paragraphs: [String] = blocks.flatMap { block -> [String] in
            let lines = block.split(separator: "\n").map { collapseSpaces(String($0)) }.filter { !$0.isEmpty }
            if joinWrappedLines {
                let joined = lines.joined(separator: " ")
                return joined.isEmpty ? [] : [joined]
            }
            return lines
        }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Fountain screenplays keep notes in `[[double brackets]]` and comments in `/* */`; neither is read aloud.
    static func normalizeFountain(_ text: String) -> String {
        let withoutNotes = text
            .replacing(/\[\[[^\]]*\]\]/, with: "")
            .replacing(/\/\*[\s\S]*?\*\//, with: "")
        return normalize(withoutNotes)
    }

    /// A title for imported text: the document name without extension, or the first words.
    static func suggestedTitle(fileName: String?, text: String) -> String {
        if let fileName {
            let base = (fileName as NSString).deletingPathExtension.trimmingCharacters(in: .whitespaces)
            if !base.isEmpty { return base }
        }
        let firstLine = CueParser.paragraphs(in: CueParser.stripCues(text)).first ?? ""
        let words = firstLine.split(separator: " ").prefix(6).joined(separator: " ")
        return words.isEmpty ? String(localized: "Untitled script") : words
    }

    private static func collapseSpaces(_ line: String) -> String {
        line.replacing(/[ \t]+/, with: " ").trimmingCharacters(in: .whitespaces)
    }
}
