//
//  VoiceToggleRow.swift
//  Cue Studio
//

import SwiftUI

/// "Write in my voice", with the voice it will use underneath. The switch is the profile's shared
/// state (the same as the Prompt card's and Profile's): turning it on before the profile has enough
/// opens the short setup, and the switch stays off until that is saved.
struct VoiceToggleRow: View {
    let summary: String

    @Environment(CreatorProfileService.self) private var profile
    @State private var setup: VoiceSetupSheet.Mode?

    var body: some View {
        Toggle(isOn: profile.writesInMyVoiceBinding { setup = .missing }) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Write in my voice").font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
        }
        .tint(Palette.successText)
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("generate.voiceToggle")
        .sheet(item: $setup) { mode in
            VoiceSetupSheet(mode: mode, profile: profile.profile)
        }
    }
}
