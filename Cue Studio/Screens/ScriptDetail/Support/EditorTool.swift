//
//  EditorTool.swift
//  Cue Studio
//

import Foundation

/// The panels that take the keyboard's place under the writing area: Improve with AI, Cues,
/// Sections and the script's options. Each has its button in the bar above the keyboard.
enum EditorTool: String, CaseIterable, Identifiable {
    case ai, cues, sections, options

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ai: String(localized: "AI")
        case .cues: String(localized: "Cues")
        case .sections: String(localized: "Sections")
        case .options: String(localized: "Options")
        }
    }
}
