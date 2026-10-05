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

        /// "Your stars" in the sky above Scripts.
        static let skyStarYou = Color(hex: 0xFFE680)
        static let skyStarYouGlow = Color(hex: 0xFFD60A, opacity: 0.6)
    }
}
