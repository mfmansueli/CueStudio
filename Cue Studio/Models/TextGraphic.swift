//
//  TextGraphic.swift
//  Cue Studio
//

import Foundation

/// A graphic laid over the video like a text (an arrow, a circle, a tag): the same graphics as Cover Studio's, drawn by the
/// same code, with a text's place, time, keyframes and ready-made motion. The text's color is its color, its size how big it
/// is, and a tag shows the text's words.
nonisolated struct TextGraphic: Codable, Hashable, Sendable {
    var kind: CoverItemKind
    /// Radians, clockwise.
    var rotation: Double = 0

    /// The text size a graphic is drawn at its cover size with (scale 1).
    static let baseSize = 40.0
}
