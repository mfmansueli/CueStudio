//
//  PanelStepper.swift
//  Cue Studio
//

import SwiftUI

/// A value with − and + ("Pauses longer than 0.7s", "Starts 00:05.2"). Held, − and + repeat (owner, canvas 2 R12, 07/11/2026),
/// and a run of steps is one undo step (`onEditingChanged`, as a slider's drag). A duration can offer common lengths
/// (`presets`): tapping the value opens them, and opening them alone changes nothing. A position (Starts, Ends) has none.
struct PanelStepper: View {
    let label: String
    let value: String
    var canDecrease = true
    var canIncrease = true
    let identifier: String
    /// Common lengths, in seconds, offered by tapping the value; empty: the value is only read.
    var presets: [TimeInterval] = []
    var onPreset: ((TimeInterval) -> Void)?
    /// A run of steps (held, or tapped in a row) begins and ends: one undo step.
    var onEditingChanged: ((Bool) -> Void)?
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    /// The common lengths a photo's or video's Duration offers, as long as it can show.
    static func commonLengths(upTo longest: TimeInterval) -> [TimeInterval] {
        [1, 2, 3, 5, 10].filter { $0 <= longest + 0.001 }
    }

    /// Ends the run of steps a moment after the last one.
    @State private var settling: Task<Void, Never>?

    var body: some View {
        HStack {
            Text(label).font(.system(.subheadline, weight: .semibold))
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                button("minus", label: Text("Less"), enabled: canDecrease, id: "\(identifier).minus", action: onDecrease)
                valueView
                    // VoiceOver: one adjustable value ("Starts, 00:05.2", swipe up or down), beside the − and + buttons.
                    .accessibilityLabel(Text(label))
                    .accessibilityValue(Text(value))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: if canIncrease { step(onIncrease) }
                        case .decrement: if canDecrease { step(onDecrease) }
                        @unknown default: break
                        }
                    }
                    .accessibilityIdentifier("\(identifier).value")
                button("plus", label: Text("More"), enabled: canIncrease, id: "\(identifier).plus", action: onIncrease)
            }
        }
        .accessibilityElement(children: .contain)
        .onDisappear { endRun() }
    }

    @ViewBuilder private var valueView: some View {
        let text = Text(value).font(.system(.subheadline, weight: .semibold).monospacedDigit()).frame(minWidth: 56)
        if presets.isEmpty || onPreset == nil {
            text
        } else {
            Menu {
                ForEach(presets, id: \.self) { seconds in
                    Button(DurationText.tenths(seconds)) { onPreset?(seconds) }
                        .accessibilityIdentifier("\(identifier).preset.\(Int((seconds * 10).rounded()))")
                }
            } label: {
                text
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 6)
                    .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.editorSegmentRadius, style: .continuous))
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
            .accessibilityHint(Text("Common lengths"))
        }
    }

    private func button(_ symbol: String, label: Text, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button { step(action) } label: {
            Image(systemName: symbol)
                .font(.editorGlyph(EditorGlyph.row, weight: .semibold))
                .foregroundStyle(enabled ? Palette.ink : Palette.ink3)
                .frame(width: 36, height: 32)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.editorSegmentRadius, style: .continuous))
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// One step of a run: the run begins with the first and ends 0.7 s after the last.
    private func step(_ action: () -> Void) {
        if settling == nil { onEditingChanged?(true) }
        settling?.cancel()
        action()
        settling = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            endRun()
        }
    }

    private func endRun() {
        guard let run = settling else { return }
        run.cancel()
        settling = nil
        onEditingChanged?(false)
    }
}
