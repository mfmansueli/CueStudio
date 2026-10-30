//
//  Platform+Logo.swift
//  Cue Studio
//

import SwiftUI

extension Platform {
    /// The network's own logo in one colour (`PlatformLogos`, template images): on the "Create for" chip and sheet, beside the platform's name.
    /// Reels and Stories share Instagram's, Shorts has YouTube Shorts' own.
    var logo: Image {
        switch self {
        case .tiktok: Image("PlatformLogos/tiktok")
        case .reels, .stories: Image("PlatformLogos/instagram")
        case .shorts: Image("PlatformLogos/youtubeshorts")
        case .youtube: Image("PlatformLogos/youtube")
        case .linkedin: Image("PlatformLogos/linkedin")
        }
    }

    /// The light that goes round the platform chip as the creator picks this network (`DockChipLight`): the network's own colours. Decorative.
    var glow: [Color] {
        switch self {
        case .tiktok: Palette.Platform.tikTokGlow
        case .reels, .stories: Palette.Platform.instagramGlow
        case .shorts, .youtube: Palette.Platform.youTubeGlow
        case .linkedin: Palette.Platform.linkedInGlow
        }
    }
}
