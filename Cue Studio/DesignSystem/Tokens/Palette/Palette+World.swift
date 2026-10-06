//
//  Palette+World.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Topics are worlds: a topic's color, and the creator's own star in the sky.
    enum World {
        /// A topic's color: up to three per creator, in this order (warm, mint, pink, sky).
        static let warm = Color(hex: 0xFFC46B)
        static let mint = Color(hex: 0x7EE0B8)
        static let pink = Color(hex: 0xFF9BD2)
        static let sky = Color(hex: 0x8FB8FF)

        /// A world drawn as a lit sphere (1.7): the highlight, the body and the shadow side.
        static let pinkSphere = [Color(hex: 0xFFE6F4), pink, Color(hex: 0xA23F78)]
        static let mintSphere = [Color(hex: 0xE6FFF5), mint, Color(hex: 0x23735C)]
        static let warmSphere = [Color(hex: 0xFFF0CC), warm, Color(hex: 0xB8682A)]

        /// The ball of YOU, from its centre outwards (1.7).
        static let youCore = [Color.white, Color(hex: 0xF2EEFF), Color(hex: 0xC9BFFF)]

        /// "Your stars" in the sky above Scripts.
        static let skyStarYou = Color(hex: 0xFFE680)
        static let skyStarYouGlow = Color(hex: 0xFFD60A, opacity: 0.6)
    }
}
