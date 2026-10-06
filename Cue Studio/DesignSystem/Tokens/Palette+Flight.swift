//
//  Palette+Flight.swift
//  Cue Studio
//

import SwiftUI

/// The colours of the first flight (v30 `handoff-telas`: onboarding 1.1–1.7 and the practice) that the roles of `Palette` don't name: the boards' own
/// inks and the lights painted into the star, camera and microphone art. The inks are bases the boards use at their own opacities.
extension Palette {
    // MARK: - Inks and lights

    /// `#E1E4F5`, the base of `ink2`, at the opacity each line of a board gives it.
    static let flightInk = Color(hex: 0xE1E4F5)
    /// `#B4A7FF`, the base of `aiText`: the lilac of rims, carets and the light of the writing.
    static let flightLilac = Color(hex: 0xB4A7FF)
    /// `#C9F1FF`: the ice-blue light of a galaxy's arrival.
    static let flightIce = Color(hex: 0xC9F1FF)
    /// `#FFE6F4`: the hot centre of a pink world's landing.
    static let flightHot = Color(hex: 0xFFE6F4)
    /// The practice's dim over its text box (`#06070E`).
    static let flightDim = Color(hex: 0x06070E)
    /// The shadow of the message card (`#281478`).
    static let flightCardShadow = Color(hex: 0x281478)

    // MARK: - The core ("YOU") and gold

    /// The two lilac stops that follow white in the core of "YOU" (`#F2EEFF`, `#C9BFFF`).
    static let flightCoreMid = Color(hex: 0xF2EEFF)
    static let flightCoreEdge = Color(hex: 0xC9BFFF)
    /// A star's light at its centre and its shades toward the edge (`#FFFBEA`, `#D99F00`, `#C99600`, `#B88A00`).
    static let flightGoldCream = Color(hex: 0xFFFBEA)
    static let flightGoldShade = Color(hex: 0xD99F00)
    static let flightGoldEdge = Color(hex: 0xC99600)
    static let flightGoldDeep = Color(hex: 0xB88A00)

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

    // MARK: - The send-off

    /// The glow round YOU (`rgba(255,200,110,.28)`), its rim (`rgba(255,240,205,.5)`), its name (`rgba(255,230,170,.75)`) and the inner orbit
    /// (`rgba(255,230,170,.22)`); the outer orbit is `starLilac` at 16%.
    static let sendOffYouGlow = Color(hex: 0xFFC86E, opacity: 0.28)
    static let sendOffYouRim = Color(hex: 0xFFF0CD, opacity: 0.5)
    static let sendOffYouName = Color(hex: 0xFFE6AA, opacity: 0.75)
    static let sendOffInnerOrbit = Color(hex: 0xFFE6AA, opacity: 0.22)
    /// A planet's name before its network has been sent to (`rgba(235,235,245,.55)`).
    static let sendOffNameDim = Color(hex: 0xEBEBF5, opacity: 0.55)

    // MARK: - Takes (6.2)

    /// The "shared" node of the pipeline: a lilac-dark disc (`#2A2160`).
    static let takesSharedNode = Color(hex: 0x2A2160)
    /// The yellow light behind the "Up next" card (`rgba(255,214,10,.14)`) and its edge (`.35`).
    static let takesUpNextGlow = Color(hex: 0xFFD60A, opacity: 0.14)
    static let takesUpNextRim = Color(hex: 0xFFD60A, opacity: 0.35)
}
