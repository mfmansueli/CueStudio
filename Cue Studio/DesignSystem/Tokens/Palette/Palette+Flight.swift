//
//  Palette+Flight.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The colours of the first flight (v30 `handoff-telas`: onboarding 1.1–1.7 and the practice) that the roles of `Palette` don't name: the boards'
    /// own inks, their night, and the lights painted into the star, camera and microphone art. The inks are bases the boards use at their own opacities.
    enum Flight {
        // MARK: - The night

        /// The night under the chapters (the boards' `.night`: `#07080E`), and the deeper one of the first star (`#06070D`).
        static let night = Color(hex: 0x07080E)
        static let nightDeep = Color(hex: 0x06070D)

        // MARK: - Inks and lights

        /// `#E1E4F5`, the base of `ink2`, at the opacity each line of a board gives it.
        static let ink = Color(hex: 0xE1E4F5)
        /// `#B4A7FF`, the base of `aiText`: the lilac of rims, carets and the light of the writing.
        static let lilac = Color(hex: 0xB4A7FF)
        /// `#C9F1FF`: the ice-blue light of a galaxy's arrival.
        static let ice = Color(hex: 0xC9F1FF)
        /// `#FFE6F4`: the hot centre of a pink world's landing.
        static let hot = Color(hex: 0xFFE6F4)
        /// The practice's dim over its text box (`#06070E`).
        static let dim = Color(hex: 0x06070E)
        /// The shadow of the message card (`#281478`).
        static let cardShadow = Color(hex: 0x281478)

        // MARK: - The core ("YOU") and gold

        /// The two lilac stops that follow white in the core of "YOU" (`#F2EEFF`, `#C9BFFF`).
        static let coreMid = Color(hex: 0xF2EEFF)
        static let coreEdge = Color(hex: 0xC9BFFF)
        /// A star's light at its centre and its shades toward the edge (`#FFFBEA`, `#D99F00`, `#C99600`, `#B88A00`).
        static let goldCream = Color(hex: 0xFFFBEA)
        static let goldShade = Color(hex: 0xD99F00)
        static let goldEdge = Color(hex: 0xC99600)
        static let goldDeep = Color(hex: 0xB88A00)

        // MARK: - The permissions art

        /// The microphone's glass, from its lit side to its dark one.
        static let micGlassLight = Color(hex: 0x54471F)
        static let micGlassMid = Color(hex: 0x241E10)
        static let micGlassDark = Color(hex: 0x0B0905)
        /// The camera's lens: the ring, the glass and the black of its core and edge.
        static let lensRingLight = Color(hex: 0x2A2550)
        static let lensRingDark = Color(hex: 0x0D0C20)
        static let lensGlassLight = Color(hex: 0x6B5FD0)
        static let lensCore = Color(hex: 0x05040F)
        static let lensEdge = Color(hex: 0x0A0920)
    }
}
