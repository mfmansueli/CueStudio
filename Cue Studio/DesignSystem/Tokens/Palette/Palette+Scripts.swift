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
        /// Apple Intelligence's light around the dock while it listens, and when an idea is sent (`AIGlow`):
        /// the app's violets, a rose, the yellow of the star and a cold blue, round the rim and back to the start. Decorative: a thin rim and
        /// a halo that fades within a few points of it.
        static let dockGlow: [Color] = [
            Color(hex: 0xB4A7FF), Color(hex: 0x7B6CFF), Color(hex: 0xFF8FD0), Color(hex: 0xFFD60A), Color(hex: 0x8FD3FF), Color(hex: 0xB4A7FF),
        ]

        /// The My Cue Voice tip's ✦ and the circle behind it (09 §3).
        static let tipGlyph = Color(hex: 0xC4B8FF)
        static let tipGlyphFill = Color(hex: 0x9D8CFF, opacity: 0.22)

        /// The idea's transition (09 §8): the cover over the screen, the halo around the star and the phrase under it.
        static let transitionCover = Color(hex: 0x07080E)
        static let transitionHalo = Color(hex: 0x9D8CFF, opacity: 0.34)
        static let transitionPhrase = Color(hex: 0xC4B8FF)
        /// The faint full circle under the progress orbit round the star (decorative).
        static let transitionOrbitTrack = Color(hex: 0xEBEBF5, opacity: 0.1)
        /// The light that crosses the page once as the star opens it (added over it, `plusLighter`; decorative, gone in 0.8 s).
        static let transitionSweep = Color(hex: 0xCFC6FF, opacity: 0.12)
        /// The idea and Cancel under the star: a soft white (`PaletteContrastTests` measures it on the cover over a white screen).
        static let transitionInk = Color(normal: Color(hex: 0xEBEBF5, opacity: 0.86), increasedContrast: Color(hex: 0xEBEBF5))
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

        // Find inspiration: the featured card (a solid violet night, so its text is measured on what is really behind it, with a softer
        // violet light from its top corner) and the chosen topic chip (violet with white words; `PaletteContrastTests` measures both).
        static let inspirationCard = Color(hex: 0x1D1A3E)
        static let inspirationCardGlow = Color(hex: 0x9D8CFF, opacity: 0.16)
        static let inspirationCardBorder = Color(hex: 0xB4A7FF, opacity: 0.34)
        static let inspirationChipOn = Color(hex: 0x6A5AE0)
        /// The light that crosses a new idea's card once (added over it, `plusLighter`; decorative, gone in 0.8 s).
        static let inspirationSweep = Color(hex: 0xCFC6FF, opacity: 0.16)

        // The empty-state mark: a ring, a violet core and a star that orbits it.
        static let emptyRing = Color(hex: 0xB4A7FF, opacity: 0.22)
        static let emptyRingCore = Color(hex: 0x9D8CFF, opacity: 0.22)
        static let emptyOrbiter = Color(hex: 0xFFE680)
        static let emptyOrbiterGlow = Color(hex: 0xFFD60A, opacity: 0.7)
    }
}
