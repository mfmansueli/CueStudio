//
//  ScriptStateStrip.swift
//  Cue Studio
//

import SwiftUI

/// The state strip under the title: the "Ready to record" switch (`ReadyToggle`; a recorded script shows RECORDED instead), then what
/// the script is in a quiet line ("Draft · List · 4 cues"), and "✦ Shape" when there are no cues. Light, with no box of its own, so it
/// reads as part of the page. The Record button is the page's own, at the bottom: one per screen. While the AI writes the strip is
/// already there, with Stop in place of Shape.
struct ScriptStateStrip: View {
    let strip: ScriptStrip
    /// The page has words: an empty one has nothing to make ready.
    var canBeReady = true
    let onShape: () -> Void
    let onReady: (Bool) -> Void
    /// The AI is writing: Stop takes the place of Shape.
    var onStop: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 10) {
            if strip.showsReadySwitch {
                ReadyToggle(isOn: strip.isReady, isEnabled: canBeReady && onStop == nil, onChange: onReady)
            } else {
                StateChip(kind: .recorded)
            }
            Text(strip.info.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(strip.isSignal ? Palette.accText : Palette.ink2)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("page.strip.info")
            if let onStop {
                Button(action: onStop) {
                    Text("Stop")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.aiTextStrong)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(Palette.aiFill, in: Capsule())
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("page.stopButton")
            } else if strip.canShape {
                shapeButton
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.strip")
    }

    /// "✦ Shape" when there are no cues.
    private var shapeButton: some View {
        Button(action: onShape) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                Text("Shape").font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Palette.aiTextStrong)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(Palette.aiFill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("page.shapeButton")
    }
}
