//
//  Platform+Tint.swift
//  Cue Studio
//

import SwiftUI

extension Platform {
    /// The dot color that tags this destination everywhere in the app.
    var tint: Color {
        switch self {
        case .tiktok: Palette.Platform.tikTok
        case .reels: Palette.Platform.reels
        case .shorts: Palette.Platform.shorts
        case .youtube: Palette.Platform.youTube
        case .linkedin: Palette.Platform.linkedIn
        case .stories: Palette.Platform.stories
        }
    }
}
