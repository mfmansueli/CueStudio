//
//  CoverTitleSuggestions.swift
//  Cue Studio
//

import Foundation

/// Which of Cue's title suggestions are worth a tap: never the one the cover already says (in any case, with any spacing), since
/// tapping it would change nothing.
nonisolated enum CoverTitleSuggestions {
    static func offered(_ suggestions: [String], title: String) -> [String] {
        let current = normalized(title)
        guard !current.isEmpty else { return suggestions }
        return suggestions.filter { normalized($0).compare(current, options: [.caseInsensitive, .widthInsensitive]) != .orderedSame }
    }

    /// The words alone, one space between them.
    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
