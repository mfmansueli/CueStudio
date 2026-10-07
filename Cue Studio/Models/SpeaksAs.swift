//
//  SpeaksAs.swift
//  Cue Studio
//

import Foundation

/// Who is talking in the creator's scripts: one person ("I") or a business, brand or team ("we"). The kind of creator suggests one
/// (`CreatorRole.suggestedSpeaksAs`); the creator's own choice wins.
nonisolated enum SpeaksAs: String, Codable, CaseIterable, Identifiable, Sendable {
    case i, we

    var id: String { rawValue }

    var label: String {
        switch self {
        case .i: String(localized: "I")
        case .we: String(localized: "We")
        }
    }

    /// What the AI reads: the pronoun the script is written in.
    var promptPronoun: String {
        switch self {
        case .i: "I"
        case .we: "we"
        }
    }
}
