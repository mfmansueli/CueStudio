//
//  ScriptMetaRow.swift
//  Cue Studio
//

import SwiftUI

/// Destination chip (opens the destination picker), format tag and capture preset.
struct ScriptMetaRow: View {
    let platform: Platform
    let formatLabel: String
    let preset: PlatformPreset
    let onDestination: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDestination) {
                HStack(spacing: 6) {
                    ColorDot(color: platform.tint)
                    Text(platform.label)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.ink2)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Palette.surface, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Destination: \(platform.label)"))
            .accessibilityHint(Text("Changes where this script will be posted"))
            .accessibilityIdentifier("detail.destinationButton")
            Text(formatLabel)
                .font(.footnote)
                .foregroundStyle(Palette.ink.opacity(0.8))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Palette.surface, in: Capsule())
            Text(preset.captureSummary)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
        }
    }
}

#if DEBUG
#Preview {
    ScriptMetaRow(platform: .tiktok, formatLabel: "Tips / list", preset: .preset(for: .tiktok, monetizationGoals: true), onDestination: {})
        .padding()
        .background(Palette.bg)
}
#endif
