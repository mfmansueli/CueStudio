//
//  OverlayColor.swift
//  Cue Studio
//

import Foundation

/// Colors a text (or its background) can take on the video. They are burned into the export, so
/// they are content, not interface tokens.
nonisolated enum OverlayColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case white, black, yellow, red, blue, green, pink
    case offBlack, orange, cyan, purple, paper

    /// Text colors in Text style and Caption style.
    static let textSwatches: [OverlayColor] = [.white, .offBlack, .yellow, .orange, .red, .green, .cyan, .purple]
    /// Behind a text (Box or Pill).
    static let backgroundSwatches: [OverlayColor] = [.yellow, .black, .white, .red, .blue, .paper]
    /// Background › Color.
    static let backdropSwatches: [OverlayColor] = [.white, .offBlack, .yellow, .red, .blue, .green, .purple]

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
        case .offBlack: (0.067, 0.067, 0.067)
        case .orange: (1, 0.624, 0.039)
        case .cyan: (0.392, 0.824, 1)
        case .purple: (0.749, 0.353, 0.949)
        case .paper: (0.957, 0.937, 0.902)
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
        case .offBlack: String(localized: "Ink")
        case .orange: String(localized: "Orange")
        case .cyan: String(localized: "Cyan")
        case .purple: String(localized: "Purple")
        case .paper: String(localized: "Paper")
        }
    }
}
