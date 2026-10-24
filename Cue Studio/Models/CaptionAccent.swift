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

    /// The palette color `color` is (its alpha aside), if it is one: what a style's own color shows as picked.
    static func matching(_ color: CaptionStyleSpec.RGB?) -> OverlayColor? {
        guard let color else { return nil }
        return palette.first { candidate in
            let parts = candidate.components
            return abs(parts.red - color.red) < 0.01 && abs(parts.green - color.green) < 0.01 && abs(parts.blue - color.blue) < 0.01
        }
    }

    /// Black or white, whichever reads better on this color (the words on a box of it).
    var readableInk: OverlayColor {
        let parts = components
        let on = ColorContrast.RGB(red: parts.red, green: parts.green, blue: parts.blue)
        let black = ColorContrast.ratio(on, ColorContrast.RGB(red: 0, green: 0, blue: 0))
        let white = ColorContrast.ratio(on, ColorContrast.RGB(red: 1, green: 1, blue: 1))
        return black >= white ? .black : .white
    }

    /// Below this (sRGB, 0 to √3) two colors read as the same: peach and blush are 0.26 apart.
    private static let minimumDistance = 0.3

    private static func distance(_ one: (red: Double, green: Double, blue: Double), _ other: (red: Double, green: Double, blue: Double)) -> Double {
        let red = one.red - other.red, green = one.green - other.green, blue = one.blue - other.blue
        return (red * red + green * green + blue * blue).squareRoot()
    }
}
