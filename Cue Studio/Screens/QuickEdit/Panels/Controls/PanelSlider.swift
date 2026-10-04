//
//  PanelSlider.swift
//  Cue Studio
//

import SwiftUI

/// A slider of the editor's panels: its name and its value written above the track. Filled from the middle for
/// −100…+100 settings. A drag is one undo step (`onEditingChanged`); VoiceOver adjusts it by 5% of the range.
/// Ranges, steps and defaults come from `CueSliderSpec`.
struct PanelSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// Where a double tap returns to, and where a soft tick sits; a bipolar slider's is its middle.
    var defaultValue: Double?
    /// Filled from the middle (Exposure, Contrast…).
    var bipolar = false
    let format: PanelValueFormat
    let identifier: String
    let onChange: (Double) -> Void
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        CueSlider(
            value: Binding(get: { value }, set: { new in
                // Whole steps, and only when the value really moved: a drag is one undo step.
                let snapped = (new / step).rounded() * step
                if abs(snapped - value) > step / 1000 { onChange(snapped) }
            }),
            range: range,
            step: step,
            defaultValue: defaultValue ?? (bipolar ? 0 : nil),
            style: .full,
            origin: bipolar ? .center : .leading,
            label: label,
            valueText: format.text(value),
            accessibilityIdentifier: identifier,
            onEditingChanged: onEditingChanged
        )
    }
}
