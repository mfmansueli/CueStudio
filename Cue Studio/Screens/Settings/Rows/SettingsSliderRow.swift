//
//  SettingsSliderRow.swift
//  Cue Studio
//

import SwiftUI

/// A slider row: the title and the value above, an optional second line, then the track between its two ends
/// ("80" … "220 wpm"). The native `Slider`, with the yellow track.
struct SettingsSliderRow: View {
    let title: String
    let valueText: String
    var detail: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var minLabel: String?
    var maxLabel: String?
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Palette.ink)
                    if let detail {
                        Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                    }
                }
                Spacer(minLength: 8)
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 10) {
                if let minLabel { endLabel(minLabel) }
                Slider(value: $value, in: range, step: step)
                    .tint(Palette.accText)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text(valueText))
                    .accessibilityIdentifier(identifier)
                if let maxLabel { endLabel(maxLabel) }
            }
        }
        .padding(.vertical, 6)
    }

    private func endLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Palette.inkHint)
            .fixedSize()
            .accessibilityHidden(true)
    }
}
