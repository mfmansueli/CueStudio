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

        /// Ultra AI's light round the writer chip as it is picked (`DockChipLight`): Cue's violets with its yellow, the star's colours. Its
        /// sparks are the violet, the lilac and the yellow (`UltraChipSparks`). Decorative.
        static let ultraGlow: [Color] = [
            Color(hex: 0x9D8CFF), Color(hex: 0xE4DEFF), Color(hex: 0xFFD60A), Color(hex: 0xB4A7FF), Color(hex: 0x7B6CFF), Color(hex: 0x9D8CFF),
        ]
        /// The send arrow while Ultra AI writes the next idea: Cue's violet, with a white arrow (4.5:1; the button 3.9:1 on the dock).
        static let ultraSend = Color(hex: 0x6F5CFF)
        static let ultraSendInk = Color.white
        /// An Ultra AI script's star in the transition: the violet of its glow, its streaks and its comet (`StarTransitionOverlay`); its
        /// gold is the sky's own star (`Palette.World.skyStarYou`). Decorative.
        static let ultraStarGlow = Color(hex: 0xA493FF)
        /// The scene round that star while Ultra AI writes (`UltraWaitScene`): the galaxy's arms and stars in Cue's violets and lilac (warming to the
        /// sky star's gold as the polish comes), its three moons (the draft's violet, the check's white, the voice's gold) and the check's beam.
        /// Decorative.
        static let ultraDust: [Color] = [Color(hex: 0x9D8CFF), Color(hex: 0xE4DEFF), Color(hex: 0x7B6CFF), Color(hex: 0xB4A7FF)]
        static let ultraMoons: [Color] = [Color(hex: 0x9D8CFF), Color(hex: 0xF4F2FF), Color(hex: 0xFFD60A)]
        static let ultraBeam = Color(hex: 0xEDEAFF)
        /// The Pro's galaxy (`ProGalaxyArt`), core to tips: Cue's gold warming out to Ultra AI's lilac and violet; and the violet one of
        /// Ultra AI's calm Pro. Each stop is a colour and where along the arm it sits. Decorative.
        static let proGalaxy: [(color: Color, at: Double)] = [
            (Color(hex: 0xFFF0A8), 0), (Color(hex: 0xFFD60A), 0.16), (Color(hex: 0xE4DEFF), 0.42), (Color(hex: 0xB4A7FF), 0.66), (Color(hex: 0x7B6CFF), 1),
        ]
        static let proGalaxyUltra: [(color: Color, at: Double)] = [
            (Color(hex: 0xF2EEFF), 0), (Color(hex: 0xCFC6FF), 0.3), (Color(hex: 0x9D8CFF), 0.65), (Color(hex: 0x7B6CFF), 1),
        ]
        /// The comets passing outside the ring while Ultra AI writes: the star's gold, a lilac and an icy blue. Decorative.
        static let ultraComets: [Color] = [Color(hex: 0xFFE680), Color(hex: 0xCFC6FF), Color(hex: 0x8FD3FF)]

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

        /// A chip of the script's settings in the dock (Format, the network): a light glass with its hairline, raised off the dock as the AI's
        /// violet ones are (`heroChipAI`), so none looks smaller than the others (a dark one did, 30/10/2026). Find inspiration takes Cue's
        /// yellow (`accSoft`, `accLine`). The hairline is decorative: the chip's words say what it is.
        static let heroChipGlass = Color(hex: 0xEBEBF5, opacity: 0.1)
        static let heroChipStroke = Color(hex: 0xEBEBF5, opacity: 0.22)
        static let heroChipAI = Color(hex: 0x9D8CFF, opacity: 0.2)
        static let heroChipAIStroke = Color(hex: 0xC4B8FF, opacity: 0.4)

        /// The soft shadow that drifts across the prompt box's golden wash.
        static let insetShade = Color.black.opacity(0.38)

        /// The "DRAFTS" group's title on the list: a purple of its own, apart from the AI's violet (`aiText`) and Reels (`Platform.reels`).
        /// 7.4:1 on `bg`, 11:1 with Increase Contrast.
        static let draftText = Color(normal: Color(hex: 0xC084FC), increasedContrast: Color(hex: 0xD8B4FE))

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
