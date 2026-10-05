//
//  ScriptStateStrip.swift
//  Cue Studio
//

import SwiftUI

/// The state strip (v29 · 4.1): the state as a chip (READY, DRAFT, RECORDED), the format and the cues in mono, "✦ Shape" when
/// there are none, and the next step: Done (plain text) for a script that can be finished. The Record button is the page's
/// own, at the bottom: one per screen. While the AI writes the strip is already there, with Stop where the next step will be.
struct ScriptStateStrip: View {
    let strip: ScriptStrip
    let onShape: () -> Void
    let onDone: () -> Void
    /// The AI is writing: Stop takes the place of Shape and Done.
    var onStop: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 8) {
            StateChip(kind: kind)
            Text(strip.info.joined(separator: " · "))
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(strip.isSignal ? Palette.accText : Palette.inkHint)
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
            } else {
                nextSteps
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: Metrics.stripHeight)
        .background(Palette.stripFill, in: RoundedRectangle(cornerRadius: Metrics.stripRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.stripRadius, style: .continuous).strokeBorder(Palette.stripRim, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.strip")
    }

    /// "✦ Shape" when there are no cues, and Done.
    @ViewBuilder
    private var nextSteps: some View {
        if strip.canShape {
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
        if strip.showsDone {
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(strip.state == .draft ? Palette.ink : Palette.ink2)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(strip.state == .draft ? Palette.fill : .clear, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("page.doneButton")
        }
    }

    private var kind: StateChip.Kind {
        switch strip.state {
        case .ready: .ready
        case .draft: .draft
        case .recorded: .recorded
        }
    }
}
