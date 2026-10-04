//
//  PanelSlider.swift
//  Cue Studio
//

import SwiftUI

/// A slider of the editor's panels (v27): the orb on a rail, its name and its value written above. Filled from the
/// middle for −100…+100 settings. A drag is one undo step (`onEditingChanged`); VoiceOver adjusts it by `step`.
struct PanelSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// Filled from the middle (Exposure, Contrast…).
    var bipolar = false
    let format: PanelValueFormat
    let identifier: String
    let onChange: (Double) -> Void
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        OrbSlider(
            value: Binding(get: { value }, set: { new in
                // Whole steps (the old slider's), and only when the value really moved: a drag is one undo step.
                let snapped = (new / step).rounded() * step
                if abs(snapped - value) > step / 1000 { onChange(snapped) }
            }),
            range: range,
            defaultValue: bipolar ? 0 : nil,
            style: .full,
            origin: bipolar ? .center : .leading,
            label: label,
            valueText: format.text(value),
            accessibilityIdentifier: identifier,
            onEditingChanged: onEditingChanged
        )
    }
}
