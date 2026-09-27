//
//  ScriptTextEditing.swift
//  Cue Studio
//

import Foundation

/// Plain text edits the editor offers without AI.
nonisolated enum ScriptTextEditing {
    static let disclosureLine = "[paid partnership] Quick heads-up: this video is sponsored."

    /// The first non-empty paragraph (the hook).
    static func opening(of text: String) -> String {
        CueParser.paragraphs(in: text).first ?? ""
    }

    /// Replaces the first paragraph, leaving the rest of the text exactly as it was.
    static func replacingOpening(of text: String, with hook: String) -> String {
        var lines = text.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return hook
        }
        lines[index] = hook
        return lines.joined(separator: "\n")
    }

    static func hasDisclosure(_ text: String) -> Bool {
        opening(of: text).range(of: "paid partnership", options: .caseInsensitive) != nil
    }

    /// Puts a sponsorship disclosure up front, where platforms and regulators expect it.
    static func addingDisclosure(to text: String) -> String {
        guard !hasDisclosure(text) else { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? disclosureLine : disclosureLine + "\n\n" + text
    }

    /// Three hook ideas starting at `rotation`, so "More options" walks through the list.
    static func hookOptions(from hooks: [String], rotation: Int) -> [String] {
        guard !hooks.isEmpty else { return [] }
        return (0..<min(3, hooks.count)).map { hooks[($0 + rotation) % hooks.count] }
    }
}
