//
//  PrompterFont.swift
//  Cue Studio
//

import Foundation

/// The teleprompter's typefaces (Settings › Prompter › Font): three from the system and two made for reading at a distance.
nonisolated enum PrompterFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, newYork = "serif", rounded, lexend, legible

    var id: String { rawValue }

    /// The typefaces' own names; they are never translated.
    var label: String {
        switch self {
        case .system: "SF Pro"
        case .newYork: "New York"
        case .rounded: "SF Rounded"
        case .lexend: "Lexend"
        case .legible: "Atkinson Hyperlegible"
        }
    }
}
