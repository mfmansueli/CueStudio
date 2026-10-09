//
//  CaptionAccent.swift
//  Cue Studio
//

import Foundation

/// Content colors, shared by the thumbnail, player and exported pixels.
nonisolated enum CaptionAccent: String, Codable, CaseIterable, Identifiable, Sendable {
    case yellow, lime, peach, white

    var id: String { rawValue }

    var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .yellow: (1, 0.86, 0.08)
        case .lime: (0.75, 1, 0.16)
        case .peach: (1, 0.73, 0.59)
        case .white: (1, 1, 1)
        }
    }

    var label: String {
        switch self {
        case .yellow: String(localized: "Yellow")
        case .lime: String(localized: "Lime")
        case .peach: String(localized: "Peach")
        case .white: String(localized: "White")
        }
    }

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

    /// Below this (sRGB, 0 to √3) two colors read as the same: Cue's yellow and the texts' yellow are
    /// 0.05 apart, peach and blush 0.26.
    private static let minimumDistance = 0.3

    private static func distance(_ one: (red: Double, green: Double, blue: Double), _ other: (red: Double, green: Double, blue: Double)) -> Double {
        let red = one.red - other.red, green = one.green - other.green, blue = one.blue - other.blue
        return (red * red + green * green + blue * blue).squareRoot()
    }
}
