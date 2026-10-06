//
//  Palette+Universe.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The night of the universe and what shines in it: the stars and their specks, the planets, the core of YOU, the creator's avatar and the
    /// send-off's map. The first flight, Your universe, the stories, the send-off and Pro draw with them.
    enum Universe {
        // MARK: - Stars

        /// The cream, warm and gold of a star's light (the welcome's star, its sparks and its trail).
        static let starCream = Color(hex: 0xFFF6C2)
        static let starWarm = Color(hex: 0xFFF0A8)
        static let starGold = Color(hex: 0xFFE680)
        /// The pale lilac of a speck of light.
        static let starLilac = Color(hex: 0xE4DEFF)

        // MARK: - The night

        /// The violet glow of the night behind a constellation.
        static let nightViolet = Color(hex: 0x9D8CFF)
        /// The night of the universe cards and the story: from this near-black at the top to the indigo at the bottom.
        static let nightDeep = Color(hex: 0x0A0B12)
        static let nightIndigo = Color(hex: 0x1B1740)
        /// The card over the universe map (a planet's popover).
        static let popover = Color(hex: 0x14162A, opacity: 0.94)

        // MARK: - The core, the avatar and the planet of Pro

        /// The thin dark line around the core ball of YOU.
        static let coreRim = Color(hex: 0x281C00, opacity: 0.4)
        /// The avatar of the creator (9.1): a violet that goes to indigo, with a faint diagonal sheen.
        static let avatarLight = Color(hex: 0x9D8CFF)
        static let avatarDeep = Color(hex: 0x5E4EE0)
        /// The planet that is you on the Pro screen: gold lit from the top left (light, mid, shade, dark).
        static let proPlanetLight = Color(hex: 0xFFF6DC)
        static let proPlanetMid = Color(hex: 0xFFD98A)
        static let proPlanetShade = Color(hex: 0xE39A3E)
        static let proPlanetDark = Color(hex: 0x3A1E10)

        // MARK: - The send-off

        /// The glow round YOU (`rgba(255,200,110,.28)`), its rim (`rgba(255,240,205,.5)`), its name (`rgba(255,230,170,.75)`) and the inner orbit
        /// (`rgba(255,230,170,.22)`); the outer orbit is `starLilac` at 16%.
        static let sendOffYouGlow = Color(hex: 0xFFC86E, opacity: 0.28)
        static let sendOffYouRim = Color(hex: 0xFFF0CD, opacity: 0.5)
        static let sendOffYouName = Color(hex: 0xFFE6AA, opacity: 0.75)
        static let sendOffInnerOrbit = Color(hex: 0xFFE6AA, opacity: 0.22)
        /// A planet's name before its network has been sent to (`rgba(235,235,245,.55)`).
        static let sendOffNameDim = Color(hex: 0xEBEBF5, opacity: 0.55)
    }
}
