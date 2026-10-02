//
//  SoundsLikeYouCard.swift
//  Cue Studio
//

import SwiftUI

/// A line in the creator's voice that updates as they change it, and the switch that sends the
/// voice to the AI. It reads the voice the AI gets on the current plan.
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
                    .foregroundStyle(Palette.accText)
                Spacer()
                Text("Live preview")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            Text("“\(sampleLine)”")
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.25), value: sampleLine)
                .accessibilityIdentifier("profile.voiceSample")
            Toggle("Use my voice in AI scripts", isOn: $profile.profile.usesVoiceInAI)
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.8))
                .tint(Palette.successText)
                .accessibilityIdentifier("profile.useVoiceToggle")
        }
        .padding(.vertical, 6)
    }

    private var sampleLine: String {
        profile.profile.voice.sampleLine
    }
}
