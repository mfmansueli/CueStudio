//
//  ScriptCueName.swift
//  Cue Studio
//

import Foundation

/// What the creator types as a new cue, made into one: no brackets or line breaks (they would break the tag), one space between
/// words, at most `maximumLength` characters.
nonisolated enum ScriptCueName {
    static let maximumLength = 24

    /// The cue's name, or nil when nothing is left of what was typed.
    static func cleaned(_ typed: String) -> String? {
        let separators = CharacterSet(charactersIn: "[]").union(.whitespacesAndNewlines)
        let words = typed.components(separatedBy: separators).filter { !$0.isEmpty }
        let name = String(words.joined(separator: " ").prefix(maximumLength)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
