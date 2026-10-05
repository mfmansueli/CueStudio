//
//  VoicePreviewSheet.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Preview" on Profile: one line the way Cue would write it for this creator, from what it knows now (the same line
/// that changes as the voice does), and the switch for using the voice in AI scripts.
struct VoicePreviewSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: String(localized: "Sounds like you"), subtitle: String(localized: "Live preview"))
            Text("“\(profile.profile.voice.sampleLine)”")
                .font(.system(.title3, design: .serif))
                .italic()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.25), value: profile.profile.voice.sampleLine)
                .accessibilityIdentifier("profile.voiceSample")
            Toggle("Use my voice in AI scripts", isOn: profile.writesInMyVoiceBinding { })
                .font(.subheadline)
                .tint(Palette.successText)
                .accessibilityIdentifier("profile.useVoiceToggle")
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
        .accessibilityIdentifier("profile.voicePreviewSheet")
    }
}
