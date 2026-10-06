//
//  Palette+Scripts.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The Scripts tab's own colors: the idea card (`hero*`), the dock, the My Cue Voice tip, the idea's star transition, the #AD tag and the empty-state mark.
    enum Scripts {
        /// The idea card (3.2 `.hero`): `#1A1840` under a violet light from the top-left and an indigo one from the bottom-right.
        static let heroBase = Color(hex: 0x1A1840)
        static let heroViolet = Color(hex: 0x9D8CFF, opacity: 0.55)
        static let heroIndigo = Color(hex: 0x5E4EE0, opacity: 0.6)
        static let heroBorder = Color(hex: 0xB4A7FF, opacity: 0.4)

        // The Scripts dock (v30, 09 §2): clean glass with two auroras, no sky inside.
        static let dockBase = Color(hex: 0x1A1840, opacity: 0.56)
        static let dockAuroraViolet = Color(hex: 0x9D8CFF, opacity: 0.36)
        static let dockAuroraIndigo = Color(hex: 0x5E4EE0, opacity: 0.40)
        static let dockRim = Color(hex: 0xC4B8FF, opacity: 0.5)

        /// The My Cue Voice tip's ✦ and the circle behind it (09 §3).
        static let tipGlyph = Color(hex: 0xC4B8FF)
        static let tipGlyphFill = Color(hex: 0x9D8CFF, opacity: 0.22)

        /// The idea's transition (09 §8): the cover over the screen, the halo around the star and the phrase under it.
        static let transitionCover = Color(hex: 0x07080E)
        static let transitionHalo = Color(hex: 0x9D8CFF, opacity: 0.34)
        static let transitionPhrase = Color(hex: 0xC4B8FF)
        static let dockField = Color(hex: 0x05060C, opacity: 0.45)

        /// A chip on the idea card (`rgba(5,6,12,0.42)`) and the voice chip's violet.
        static let heroChip = Color(hex: 0x05060C, opacity: 0.42)
        static let heroChipAI = Color(hex: 0x9D8CFF, opacity: 0.2)
        static let heroChipAIStroke = Color(hex: 0xC4B8FF, opacity: 0.4)

        /// The soft shadow that drifts across the prompt box's golden wash.
        static let insetShade = Color.black.opacity(0.38)

        /// The "#AD" / "AD" tag: black on yellow.
        static let adTagFill = Palette.acc
        static let adTagInk = Color.black

        // The empty-state mark: a ring, a violet core and a star that orbits it.
        static let emptyRing = Color(hex: 0xB4A7FF, opacity: 0.22)
        static let emptyRingCore = Color(hex: 0x9D8CFF, opacity: 0.22)
        static let emptyOrbiter = Color(hex: 0xFFE680)
        static let emptyOrbiterGlow = Color(hex: 0xFFD60A, opacity: 0.7)
    }
}
