//
//  PlatformDot.swift
//  Cue Studio
//

import SwiftUI

/// A social network's marker (v29): a 6–7 pt circle in the platform's galaxy color (`Platform.tint`). A
/// network is a dot, never a bar (a bar is a topic: `ThemeRail`). Decorative: the platform's name is
/// always written beside it.
struct PlatformDot: View {
    var color: Color
    /// 6 pt for dense lines (HUD, chips), 7 pt otherwise.
    var isSmall = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(
                width: isSmall ? Metrics.platformDotSmallSize : Metrics.platformDotSize,
                height: isSmall ? Metrics.platformDotSmallSize : Metrics.platformDotSize
            )
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 12) {
        PlatformDot(color: Palette.Platform.tikTok)
        PlatformDot(color: Palette.Platform.reels, isSmall: true)
        PlatformDot(color: Palette.Platform.shorts)
        PlatformDot(color: Palette.Platform.youTube, isSmall: true)
    }
    .padding()
    .background(Palette.bg)
}
#endif
