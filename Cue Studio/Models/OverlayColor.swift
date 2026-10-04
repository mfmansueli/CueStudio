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
    /// The v27 swatches: lavender (the AI's violet), blush and mint (the worlds' pink and green).
    case lavender, blush, mint

    /// Text colors in Text style and Caption style.
    static let textSwatches: [OverlayColor] = [.white, .yellow, .lavender, .cyan, .blush, .mint, .offBlack]
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
        case .lavender: (0.706, 0.655, 1)
        case .blush: (1, 0.608, 0.824)
        case .mint: (0.494, 0.878, 0.722)
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
        case .lavender: String(localized: "Lavender")
        case .blush: String(localized: "Blush")
        case .mint: String(localized: "Mint")
        }
    }
}
