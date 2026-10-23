//
//  OverlayColor.swift
//  Cue Studio
//

import Foundation

/// Colors words, boxes, graphics, highlights and the video's background can take. They are burned
/// into the export, so they are content, not interface tokens. Every color picker of the editor and
/// the cover offers the same palette, in the same order; black, green, pink and purple stay for
/// edits that picked them before.
nonisolated enum OverlayColor: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = OverlayColor.white

    case white, black, yellow, red, blue, green, pink
    case offBlack, orange, cyan, purple, paper
    /// The v27 swatches: lavender (the AI's violet), blush and mint (the worlds' pink and green).
    case lavender, blush, mint
    /// The captions' highlights before the palette.
    case peach, lime

    /// The palette: text, its box, graphics, the captions and their highlight, the cover's words and the video's
    /// background all pick from it.
    static let palette: [OverlayColor] = [
        .white, .paper, .offBlack, .yellow, .peach, .orange, .red, .blush, .lavender, .blue, .cyan, .mint, .lime,
    ]

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
        case .peach: (1, 0.729, 0.588)
        case .lime: (0.749, 1, 0.161)
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
        case .peach: String(localized: "Peach")
        case .lime: String(localized: "Lime")
        }
    }
}
