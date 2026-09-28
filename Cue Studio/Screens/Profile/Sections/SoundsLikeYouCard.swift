//
//  SoundsLikeYouCard.swift
//  Cue Studio
//

import SwiftUI

/// A line in the creator's voice that updates as they change it, and the switch that sends the
/// voice to the AI.
struct SoundsLikeYouCard: View {
    @Environment(CreatorProfileService.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sounds like you", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(Palette.acc)
                Spacer()
                Text("Live preview")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            Text("“\(profile.profile.voice.sampleLine)”")
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.25), value: profile.profile.voice.sampleLine)
                .accessibilityIdentifier("profile.voiceSample")
            Toggle("Use my voice in AI scripts", isOn: $profile.profile.usesVoiceInAI)
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.8))
                .tint(Palette.success)
                .accessibilityIdentifier("profile.useVoiceToggle")
        }
        .padding(.vertical, 6)
    }
}
