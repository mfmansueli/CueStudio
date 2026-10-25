//
//  OverlayColor.swift
//  Cue Studio
//

import Foundation

/// Colors words, boxes, graphics, highlights and the video's background can take. They are burned
/// into the export, so they are content, not interface tokens. Every color picker of the editor and
/// the cover offers the same palette, in the same order; black, green, pink and purple stay for
/// edits that picked them before. Any other color is a creator's own (a brand's, picked with the system's color picker),
/// saved as "#RRGGBB": an earlier version of Cue reads it as white (`LenientChoice`).
nonisolated struct OverlayColor: LenientChoice, CaseIterable, Identifiable, Hashable, Sendable, CustomStringConvertible {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = OverlayColor.white

    /// The color's name ("yellow"), or "#RRGGBB" for a creator's own.
    let rawValue: String

    init?(rawValue: String) {
        if Self.named[rawValue] != nil {
            self.rawValue = rawValue
        } else if let parts = Self.hexComponents(rawValue) {
            self.rawValue = Self.hex(parts)
        } else {
            return nil
        }
    }

    private init(named name: String) {
        rawValue = name
    }

    static let white = OverlayColor(named: "white")
    static let black = OverlayColor(named: "black")
    static let yellow = OverlayColor(named: "yellow")
    static let red = OverlayColor(named: "red")
    static let blue = OverlayColor(named: "blue")
    static let green = OverlayColor(named: "green")
    static let pink = OverlayColor(named: "pink")
    static let offBlack = OverlayColor(named: "offBlack")
    static let orange = OverlayColor(named: "orange")
    static let cyan = OverlayColor(named: "cyan")
    static let purple = OverlayColor(named: "purple")
    static let paper = OverlayColor(named: "paper")
    /// The v27 swatches: lavender (the AI's violet), blush and mint (the worlds' pink and green).
    static let lavender = OverlayColor(named: "lavender")
    static let blush = OverlayColor(named: "blush")
    static let mint = OverlayColor(named: "mint")
    /// The captions' highlights before the palette.
    static let peach = OverlayColor(named: "peach")
    static let lime = OverlayColor(named: "lime")

    /// The named colors, in the order they were added.
    static let allCases: [OverlayColor] = [
        .white, .black, .yellow, .red, .blue, .green, .pink, .offBlack, .orange, .cyan, .purple, .paper, .lavender, .blush, .mint,
        .peach, .lime,
    ]

    /// The palette: text, its box, graphics, the captions and their highlight, the cover's words and the video's
    /// background all pick from it.
    static let palette: [OverlayColor] = [
        .white, .paper, .offBlack, .yellow, .peach, .orange, .red, .blush, .lavender, .blue, .cyan, .mint, .lime,
    ]

    /// A creator's own color, from sRGB components (0 to 1), on the 256 steps "#RRGGBB" keeps; a named color when it is one.
    static func custom(red: Double, green: Double, blue: Double) -> OverlayColor {
        let raw = hex((red, green, blue))
        let parts = hexComponents(raw) ?? (red, green, blue)
        if let name = allCases.first(where: { same($0.components, parts) }) { return name }
        return OverlayColor(named: raw)
    }

    /// A creator's own color, not one of the named ones.
    var isCustom: Bool { Self.named[rawValue] == nil }

    var id: String { rawValue }

    /// Its name, as when it was an enum (the pickers' identifiers, "edit.textColor.yellow").
    var description: String { rawValue }

    /// sRGB components, 0 to 1.
    var components: (red: Double, green: Double, blue: Double) {
        Self.named[rawValue]?.components ?? Self.hexComponents(rawValue) ?? (1, 1, 1)
    }

    var label: String {
        guard let named = Self.named[rawValue] else {
            return String(localized: "Color \(rawValue)", comment: "A creator's own color, by its hex code (“Color #1E66F5”)")
        }
        return named.label()
    }

    // MARK: - Private

    private static let named: [String: (components: (red: Double, green: Double, blue: Double), label: @Sendable () -> String)] = [
        "white": ((1, 1, 1), { String(localized: "White") }),
        "black": ((0, 0, 0), { String(localized: "Black") }),
        "yellow": ((1, 0.839, 0.039), { String(localized: "Yellow") }),
        "red": ((1, 0.271, 0.227), { String(localized: "Red") }),
        "blue": ((0.039, 0.518, 1), { String(localized: "Blue") }),
        "green": ((0.204, 0.78, 0.349), { String(localized: "Green") }),
        "pink": ((1, 0.216, 0.373), { String(localized: "Pink") }),
        "offBlack": ((0.067, 0.067, 0.067), { String(localized: "Ink") }),
        "orange": ((1, 0.624, 0.039), { String(localized: "Orange") }),
        "cyan": ((0.392, 0.824, 1), { String(localized: "Cyan") }),
        "purple": ((0.749, 0.353, 0.949), { String(localized: "Purple") }),
        "paper": ((0.957, 0.937, 0.902), { String(localized: "Paper") }),
        "lavender": ((0.706, 0.655, 1), { String(localized: "Lavender") }),
        "blush": ((1, 0.608, 0.824), { String(localized: "Blush") }),
        "mint": ((0.494, 0.878, 0.722), { String(localized: "Mint") }),
        "peach": ((1, 0.729, 0.588), { String(localized: "Peach") }),
        "lime": ((0.749, 1, 0.161), { String(localized: "Lime") }),
    ]

    private static func hex(_ parts: (red: Double, green: Double, blue: Double)) -> String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(parts.red), byte(parts.green), byte(parts.blue))
    }

    /// The components of "#RRGGBB" (any case), nil for anything else.
    private static func hexComponents(_ raw: String) -> (red: Double, green: Double, blue: Double)? {
        guard raw.count == 7, raw.first == "#", let value = UInt32(raw.dropFirst(), radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    private static func same(_ one: (red: Double, green: Double, blue: Double), _ other: (red: Double, green: Double, blue: Double)) -> Bool {
        abs(one.red - other.red) < 0.5 / 255 && abs(one.green - other.green) < 0.5 / 255 && abs(one.blue - other.blue) < 0.5 / 255
    }

    static func == (lhs: OverlayColor, rhs: OverlayColor) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
