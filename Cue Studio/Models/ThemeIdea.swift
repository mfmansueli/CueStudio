//
//  ThemeIdea.swift
//  Cue Studio
//

import Foundation

/// A video idea for the creator's niche ("3 things I stopped buying this year · List · ~1 min").
nonisolated struct ThemeIdea: Hashable, Identifiable, Sendable {
    var title: String
    /// Kind of video: List, Routine, Tutorial…
    var kind: String
    var length: ScriptLength
    var niche: Niche

    var id: String { "\(niche.rawValue).\(title)" }

    /// "List · ~1 min · Lifestyle"
    var meta: String {
        "\(kind) · ~\(length.label) · \(niche.label)"
    }

    /// What "Use" puts in the prompt box: "1 min list video: 3 things I stopped buying this year".
    var prompt: String {
        String(localized: "\(length.label) \(kind.lowercased()) video: \(title)")
    }
}
