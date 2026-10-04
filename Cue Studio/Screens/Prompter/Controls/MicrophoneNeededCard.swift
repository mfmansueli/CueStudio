//
//  MicrophoneNeededCard.swift
//  Cue Studio
//

import SwiftUI

/// Without the microphone's permission recording is off (04 · F3): "Cue needs the microphone", and the way to Settings. The
/// prompter keeps working; only Record waits.
struct MicrophoneNeededCard: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.warnText)
                .frame(width: 36, height: 36)
                .background(Palette.warn.opacity(0.18), in: Circle())
            Text("Cue needs the microphone")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.cueGlass(.compact, expands: false))
            .accessibilityIdentifier("prompter.openSettingsButton")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .background(Palette.warningCard, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prompter.microphoneCard")
    }
}
