//
//  Platform+Tint.swift
//  Cue Studio
//

import SwiftUI

extension Platform {
    /// The dot color that tags this destination everywhere in the app.
    var tint: Color {
        switch self {
        case .tiktok: Palette.platformTikTok
        case .reels: Palette.platformReels
        case .shorts: Palette.platformShorts
        case .youtube: Palette.platformYouTube
        }
    }
}
