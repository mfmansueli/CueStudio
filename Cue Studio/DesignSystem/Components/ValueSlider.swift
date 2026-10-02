//
//  ValueSlider.swift
//  Cue Studio
//

import SwiftUI

/// Slider row with a title and its current value on the right.
struct ValueSlider: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// Words under both ends of the track ("Narrow" / "Wide").
    var ends: (min: String, max: String)?
    var identifier: String?

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink2)
            }
            .font(.body)
            .frame(minHeight: 36)
            Slider(value: $value, in: range, step: step)
                .tint(Palette.acc)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(valueText))
                .accessibilityIdentifier(identifier ?? "")
            if let ends {
                HStack {
                    Text(ends.min)
                    Spacer()
                    Text(ends.max)
                }
                .font(.caption2)
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            }
        }
        .padding(.bottom, 6)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var size = 28.0
    ValueSlider(title: "Text size", valueText: "\(Int(size))", value: $size, range: 16...56)
        .padding()
        .background(Palette.surface2)
}
#endif
