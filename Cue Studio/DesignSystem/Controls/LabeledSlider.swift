//
//  LabeledSlider.swift
//  Cue Studio
//

import SwiftUI

/// The system's `Slider` with its name and value written above it ("SPEED · 150 wpm"), for the recorder's bars. VoiceOver reads the
/// name and `spokenValue` (the value in words), and adjusts it in its steps.
struct LabeledSlider: View {
    let label: String
    let valueText: String
    var spokenValue: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Nil slides freely.
    let step: Double?
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink2)
                Spacer(minLength: 8)
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .font(.caption.weight(.semibold))
            .accessibilityHidden(true)
            slider
                .tint(Palette.acc)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(spokenValue ?? valueText))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var slider: some View {
        if let step {
            Slider(value: $value, in: range, step: step)
        } else {
            Slider(value: $value, in: range)
        }
    }
}
