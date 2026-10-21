//
//  Palette+Settings.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Settings: the icon tiles of its rows, in three families of the app's own colours (owner's choice, 21/10/2026): yellow for what a
    /// creator records with, violet for the AI, a quiet grey for the rest, and Cue Pro a solid yellow tile. Each tile is its colour, lighter
    /// at the top, over the row's card; the glyph is the family's colour (`SettingsIcon`).
    enum Settings {
        static let toolGlyph = Palette.acc
        static let toolTileTop = Color(hex: 0xFFD60A, opacity: 0.22)
        static let toolTileBottom = Color(hex: 0xFFD60A, opacity: 0.10)

        static let aiGlyph = Color(hex: 0xBBAAFF)
        static let aiTileTop = Color(hex: 0xAA96FF, opacity: 0.26)
        static let aiTileBottom = Color(hex: 0xAA96FF, opacity: 0.12)

        static let generalGlyph = Color(hex: 0xCDD0E0)
        static let generalTileTop = Color(hex: 0xFFFFFF, opacity: 0.10)
        static let generalTileBottom = Color(hex: 0xFFFFFF, opacity: 0.05)

        static let proGlyph = Color(hex: 0x1A1500)
        static let proTileTop = Color(hex: 0xFFE27A)
        static let proTileBottom = Palette.acc

        /// The thin light along a tile's top edge, as on glass.
        static let tileRim = Color(hex: 0xFFFFFF, opacity: 0.16)

        /// Cue's own app icon as `AppIconArt` draws it (the layers of `AppIcon.icon`): its night, the script's lines and the reading line.
        static let iconNightTop = Color(.displayP3, red: 0.14118, green: 0.12549, blue: 0.34902)
        static let iconNightBottom = Color(.displayP3, red: 0.05098, green: 0.04314, blue: 0.16078)
        static let iconLines = Color(hex: 0xC4C2D6)
        static let iconGuide = Color(hex: 0xFAD84A)

        /// The violet some skies are lit with (`BgWash`).
        static let iconIndigo = Color(hex: 0x5E4EE0)
    }
}
