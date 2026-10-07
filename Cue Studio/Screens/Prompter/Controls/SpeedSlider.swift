//
//  SpeedSlider.swift
//  Cue Studio
//

import SwiftUI

/// "SPEED  1×": the speed of the prompter's bars as a multiple of the natural reading pace (`SpeedScale`), on the system's slider. It moves
/// from stop to stop (0.5× · 0.8× · 1× · 1.2× · 1.5× · 2× · 3× · 4× · 5×), and each stop it reaches is felt as a light tick. The value is always
/// written.
struct SpeedSlider: View {
    let speed: Double
    let onChange: @MainActor @Sendable (Double) -> Void

    var body: some View {
        let stops = SpeedScale.stops
        let current = SpeedScale.nearestStop(toSpeed: speed)
        LabeledSlider(
            label: String(localized: "Speed"),
            valueText: SpeedScale.label(forMultiple: stops[current]),
            value: Binding(
                get: { Double(current) },
                set: { newValue in
                    let index = min(stops.count - 1, max(0, Int(newValue.rounded())))
                    guard index != current else { return }
                    Haptics.selection()
                    onChange(SpeedScale.speed(forMultiple: stops[index]))
                }
            ),
            range: 0...Double(stops.count - 1),
            step: 1,
            accessibilityIdentifier: "prompter.speedSlider"
        )
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    SpeedSlider(speed: ReadTime.naturalSpeed, onChange: { _ in })
        .padding()
        .background(Color.black)
}
#endif
