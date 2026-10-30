//
//  CaptionSpokenHighlight.swift
//  Cue Studio
//

import Foundation

/// How the word being said stands out, for as long as it is said (Caption style › Animation › Word being said): in the
/// highlight color, on a box, on a box that slides from word to word, or popping a little bigger in the highlight color.
/// The layout never moves: the box and the pop are drawn over it. It lasts only while the word is said, unlike the words the
/// creator marked for emphasis (`CaptionCue.emphasis`), which stay.
nonisolated enum CaptionSpokenHighlight: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionSpokenHighlight.color

    case none, color, box, glide, pop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .color: String(localized: "Color")
        case .box: String(localized: "Box")
        case .glide: String(localized: "Sliding box")
        case .pop: String(localized: "Pop")
        }
    }

    var systemImage: String {
        switch self {
        case .none: "textformat"
        case .color: "highlighter"
        case .box: "character.textbox"
        case .glide: "arrow.left.and.right.square"
        case .pop: "textformat.size.larger"
        }
    }

    /// Draws a box behind the word.
    var boxes: Bool { self == .box || self == .glide }

    /// How much bigger a popped word is drawn.
    static let popScale = 1.12
    /// How long the sliding box takes from one word to the next.
    static let glideDuration: TimeInterval = 0.09
}
