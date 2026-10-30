//
//  Palette+Platform.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Platforms are galaxies: each network's color.
    enum Platform {
        static let tikTok = Color(hex: 0x64D2FF)
        static let reels = Color(hex: 0xBF5AF2)
        static let shorts = Color(hex: 0xFF6B5A)
        static let youTube = Color(hex: 0xFF9F0A)
        static let linkedIn = Color(hex: 0x0A84FF)
        static let stories = Color(hex: 0xFF6FA8)
        static let neutral = Color(hex: 0x8E8E93)

        /// The light round the platform chip as a network is picked (`Platform.glow`): each network's own colours. Decorative, never text.
        static let tikTokGlow: [Color] = [
            Color(hex: 0x25F4EE), Color(hex: 0xFFFFFF), Color(hex: 0xFE2C55), Color(hex: 0x25F4EE),
        ]
        static let instagramGlow: [Color] = [
            Color(hex: 0xFEDA75), Color(hex: 0xFA7E1E), Color(hex: 0xD62976), Color(hex: 0x962FBF), Color(hex: 0x4F5BD5), Color(hex: 0xFEDA75),
        ]
        static let youTubeGlow: [Color] = [Color(hex: 0xFF0033), Color(hex: 0xFFFFFF), Color(hex: 0xFF0033)]
        static let linkedInGlow: [Color] = [Color(hex: 0x0A66C2), Color(hex: 0x70B5F9), Color(hex: 0x0A66C2)]
    }
}
