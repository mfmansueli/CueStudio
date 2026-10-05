//
//  Palette+Aurora.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The auroras: behind the idea and "Sounds like you" cards, and the night glow of the navigation screens.
    enum Aurora {
        /// Aurora behind the idea and "Sounds like you" cards: the violet and the indigo that drift across
        /// the dark surface.
        static let violet = Color(hex: 0x9D8CFF, opacity: 0.30)
        static let indigo = Color(hex: 0x5E4EE0, opacity: 0.30)

        /// The light that runs around those cards' border: lilac.
        static let borderLight = Color(hex: 0xB4A7FF)

        /// The thin yellow scan line along the bottom edge of those cards.
        static let scanLine = Color(hex: 0xFFD60A)

        /// Night glow of the navigation screens (`BgWash`): a violet light from the top left and an indigo
        /// one on the right, over `bg`. The same on every screen, empty states included.
        static let bgWashViolet = Color(hex: 0x9D8CFF, opacity: 0.2)
        static let bgWashIndigo = Color(hex: 0x5E4EE0, opacity: 0.12)
    }
}
