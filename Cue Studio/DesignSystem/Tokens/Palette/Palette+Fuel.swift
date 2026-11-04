//
//  Palette+Fuel.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// My Cue Voice's fuel tank (`VoiceFuelPainter`, the owner, 03/11/2026): a glass tube of deep night filled with yellow plasma to what Cue
    /// knows. The plasma against the empty tube is what informs (3:1, `PaletteContrastTests`); the glass, the current and the lit front are
    /// decoration.
    enum Fuel {
        /// The empty tube: deeper than the surfaces it sits on, so the plasma reads as filling it.
        static let tank = Color(hex: 0x0D0B26)
        /// Its rim and the quarter marks etched on it.
        static let rim = Color(hex: 0x6E7496, opacity: 0.55)
        /// The plasma's front layer: the app's yellow on top, a warmer amber at the bottom.
        static let fuel = Palette.acc
        static let fuelDeep = Color(hex: 0xF5A300)
        /// The layer behind it, moving on its own, darker: the depth of the liquid.
        static let fuelBack = Color(hex: 0xB86E00)
        /// The front, lit where the plasma meets the empty tube.
        static let meniscus = Color(hex: 0xFFF6C8)
        /// The pulse of light passing through the plasma.
        static let current = Color(hex: 0xFFFBE6)
        /// The rings of force behind the ship as it comes at the viewer: the engines' blue, almost white.
        static let forceRing = Color(hex: 0xD8F4FF)
        /// The glass: the shadow under its top edge and the light along it.
        static let innerShadow = Color.black.opacity(0.45)
        static let glassLight = Color.white.opacity(0.32)
    }
}
