//
//  GenerateTab.swift
//  Cue Studio
//

import Foundation

/// The three ways "Generate with AI" starts: a free prompt, an idea for the creator's niche, or a
/// structured format.
nonisolated enum GenerateTab: String, CaseIterable, Identifiable, Sendable {
    case prompt, themes, formats

    var id: String { rawValue }

    var label: String {
        switch self {
        case .prompt: String(localized: "Prompt")
        case .themes: String(localized: "Themes")
        case .formats: String(localized: "Formats")
        }
    }
}
