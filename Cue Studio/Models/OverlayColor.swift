//
//  OverlayColor.swift
//  Cue Studio
//

import Foundation

/// Colors a text (or its background) can take on the video. They are burned into the export, so
/// they are content, not interface tokens.
nonisolated enum OverlayColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case white, black, yellow, red, blue, green, pink

    var id: String { rawValue }

    /// sRGB components, 0 to 1.
    var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .white: (1, 1, 1)
        case .black: (0, 0, 0)
        case .yellow: (1, 0.839, 0.039)
        case .red: (1, 0.271, 0.227)
        case .blue: (0.039, 0.518, 1)
        case .green: (0.204, 0.78, 0.349)
        case .pink: (1, 0.216, 0.373)
        }
    }

    var label: String {
        switch self {
        case .white: String(localized: "White")
        case .black: String(localized: "Black")
        case .yellow: String(localized: "Yellow")
        case .red: String(localized: "Red")
        case .blue: String(localized: "Blue")
        case .green: String(localized: "Green")
        case .pink: String(localized: "Pink")
        }
    }
}
