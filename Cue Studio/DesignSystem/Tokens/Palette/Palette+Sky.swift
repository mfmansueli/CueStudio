//
//  Palette+Sky.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The starry sky's own colours (Settings › Personalize › Starry sky): the Interstellar night and its glow, the nebulae, the Milky Way band,
    /// the spaceship and the astronaut of Adrift. The night and its glow are what text sits on (`PaletteContrastTests`); the rest is decoration.
    enum Sky {
        // MARK: - Interstellar

        /// Deep space under the browse screens: darker than `bg` (`#0A0B12`), so the colours of the nebulae have more night to stand out from.
        static let interstellarBg = Color(hex: 0x030409)
        /// The night glow of Interstellar (`BgWash.interstellar`): a deep indigo light from the top left, a magenta one on the right and a teal one
        /// at the bottom left. Strong enough to feel, light enough that `inkHint` still reads at the brightest point (`PaletteContrastTests`).
        static let interstellarWashIndigo = Color(hex: 0x4A3FD0, opacity: 0.20)
        static let interstellarWashMagenta = Color(hex: 0xB0408F, opacity: 0.12)
        static let interstellarWashTeal = Color(hex: 0x1F8FA8, opacity: 0.11)
        /// The nebulae's own colours (solid: each nebula carries its own peak opacity, `StarfieldMath.Nebula.opacity`).
        static let nebulaViolet = Color(hex: 0x9D8CFF)
        static let nebulaBlue = Color(hex: 0x3D5BFF)
        static let nebulaMagenta = Color(hex: 0xC2449E)
        static let nebulaTeal = Color(hex: 0x2BB3C8)
        /// The Milky Way band of Interstellar and its dust (solid; the band's peak opacity is `StarfieldMath.bandPeakOpacity`).
        static let interstellarBand = Color(hex: 0x8FA6FF)

        // MARK: - The spaceship

        /// A faceted pale hull (light above, shaded below), deep indigo wings with a cyan edge light, ion-blue engines that leave a trail fading
        /// to violet, and two small wingtip lights. Decoration only.
        static let shipHull = Color(hex: 0xE4E9FF)
        static let shipHullShade = Color(hex: 0x8E97C9)
        static let shipWing = Color(hex: 0x3F43B0)
        static let shipEngine = Color(hex: 0x5FD4FF)
        static let shipTrailFar = Color(hex: 0x7A6CE0)
        static let shipLightPort = Color(hex: 0xFF7A8A)
        static let shipLightStarboard = Color(hex: 0x7DFFC8)

        // MARK: - The astronaut of Adrift

        /// A white suit (lit from the top left, shaded toward the bottom right), grey joints, gloves, boots and pack, and a square mirrored visor,
        /// dark with silver reflections. Decoration only (see `DESIGN_PROJECT.md` §5.0.1 on the contrast).
        static let astronautSuit = Color(hex: 0xF6F7FF)
        static let astronautSuitShade = Color(hex: 0xBCC3E0)
        static let astronautSuitDeep = Color(hex: 0x8C94B8)
        static let astronautVisorTop = Color(hex: 0x2A3170)
        static let astronautVisorBottom = Color(hex: 0x05060F)
        static let astronautSilver = Color(hex: 0xE8ECF9)
        static let astronautGlint = Color(hex: 0x9FE7FF)
    }
}
