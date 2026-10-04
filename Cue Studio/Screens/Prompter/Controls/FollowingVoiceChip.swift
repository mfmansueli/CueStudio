//
//  FollowingVoiceChip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ FOLLOWING YOUR VOICE", at the bottom left of the text, while recognition follows the words.
struct FollowingVoiceChip: View {
    var body: some View {
        Text("✦ FOLLOWING YOUR VOICE")
            .font(CueStudioFont.hud)
            .tracking(1.1)
            .foregroundStyle(Palette.aiTextStrong)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Palette.aiFill, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .allowsHitTesting(false)
            .accessibilityIdentifier("prompter.followingChip")
    }
}
