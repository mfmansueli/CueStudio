//
//  CaptionAccent.swift
//  Cue Studio
//

import Foundation

/// The color the word being said takes on the captions: one of the palette's (`OverlayColor`). Highlights saved before
/// the palette (yellow, lime, peach, white) read as the same colors.
typealias CaptionAccent = OverlayColor

nonisolated extension OverlayColor {
    /// The order a lit word's color is looked for when the one asked for doesn't stand out.
    static let preference: [CaptionAccent] = [.yellow, .white, .lime, .peach]

    /// Whether the word being said, lit in this color, stands out on captions drawn with `look`:
    /// it isn't the text's own color, nor the fill behind the words.
    func standsOut(on look: TextLook) -> Bool {
        guard Self.distance(components, look.color.components) >= Self.minimumDistance else { return false }
        guard look.background != .none, look.backgroundOpacity >= 0.3 else { return true }
        return Self.distance(components, look.backgroundColor.components) >= Self.minimumDistance
    }

    /// This color when it stands out on `look`, else the first that does (`preference`).
    func standingOut(on look: TextLook) -> CaptionAccent {
        if standsOut(on: look) { return self }
        return Self.preference.first { $0.standsOut(on: look) } ?? self
    }

    /// Below this (sRGB, 0 to √3) two colors read as the same: peach and blush are 0.26 apart.
    private static let minimumDistance = 0.3

    private static func distance(_ one: (red: Double, green: Double, blue: Double), _ other: (red: Double, green: Double, blue: Double)) -> Double {
        let red = one.red - other.red, green = one.green - other.green, blue = one.blue - other.blue
        return (red * red + green * green + blue * blue).squareRoot()
    }
}
