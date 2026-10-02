//
//  VoiceToggleRow.swift
//  Cue Studio
//

import SwiftUI

/// "Write in my voice", with the voice it will use underneath.
struct VoiceToggleRow: View {
    @Binding var isOn: Bool
    let summary: String

    var body: some View {
        Toggle(isOn: $isOn) {
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
    }
}
