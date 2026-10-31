//
//  ScriptStateStrip.swift
//  Cue Studio
//

import SwiftUI

/// The state strip under the title: the "Ready to record" switch (`ReadyToggle`; a recorded script shows RECORDED instead), and beside
/// RECORDED, in yellow, "Changed since take 3" once the words have moved on from the take. Nothing else shares the row, so the switch
/// always says its whole name (owner, 31/10/2026: the line of details and "✦ Shape" squeezed it to "Ready to r…"; Shape is in the
/// tools row, `ScriptToolsRow`). Light, with no box of its own, so it reads as part of the page. The Record button is the page's own,
/// at the bottom: one per screen. While the AI writes the strip is already there, with Stop at its end.
struct ScriptStateStrip: View {
    let strip: ScriptStrip
    /// The page has words: an empty one has nothing to make ready.
    var canBeReady = true
    let onReady: (Bool) -> Void
    /// The AI is writing: Stop is at the end of the strip.
    var onStop: (() -> Void)?

    var body: some View {
        // At the accessibility text sizes what follows the switch goes under it, as the system's own rows do.
        ReflowStack(spacing: 10) {
            if strip.showsReadySwitch {
                ReadyToggle(isOn: strip.isReady, isEnabled: canBeReady && onStop == nil, onChange: onReady)
            } else {
                StateChip(kind: .recorded)
            }
            if let signal = strip.signal {
                Text(signal)
                    .cueFont(.subheadline)
                    .foregroundStyle(Palette.accText)
                    .accessibilityIdentifier("page.strip.info")
            }
            if let onStop {
                Spacer(minLength: 0)
                stopButton(onStop)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.strip")
    }

    private func stopButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Stop")
                .cueFont(14, weight: .semibold)
                .foregroundStyle(Palette.aiTextStrong)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .frame(minHeight: 32)
                .background(Palette.aiFill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("page.stopButton")
    }
}
