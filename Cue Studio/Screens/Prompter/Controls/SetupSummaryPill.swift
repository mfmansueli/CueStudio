//
//  SetupSummaryPill.swift
//  Cue Studio
//

import SwiftUI

/// Next to the microphone pill: the quality and frame the take records in ("4K · 9:16"), so the
/// creator can check the setup before tapping record. When the values come from a platform
/// recommendation or were changed for this take, it says so ("TikTok setup · 1080p · 9:16"). Opens
/// "This take".
struct SetupSummaryPill: View {
    /// "4K · 9:16"
    let summary: String
    let source: SetupSource
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if source != .creatorSetup {
                    Text(source.label)
                        .foregroundStyle(Palette.accText)
                    Text("·")
                        .foregroundStyle(Palette.ink3)
                }
                Text(summary)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minHeight: 26)
            .background(Palette.overlayFill, in: Capsule())
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Recording setup"))
        .accessibilityValue(Text(source == .creatorSetup ? summary : "\(source.label), \(summary)"))
        .accessibilityHint(Text("Shows what this take records with and where it comes from"))
        .accessibilityIdentifier("prompter.setupButton")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        SetupSummaryPill(summary: "4K · 9:16", source: .creatorSetup, isEnabled: true) {}
        SetupSummaryPill(summary: "1080p · 9:16", source: .recommended(.tiktok), isEnabled: true) {}
        SetupSummaryPill(summary: "4K · 1:1", source: .thisTake, isEnabled: true) {}
    }
    .padding()
    .background(Palette.bg)
}
#endif
