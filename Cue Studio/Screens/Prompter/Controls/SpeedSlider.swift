//
//  SpeedSlider.swift
//  Cue Studio
//

import SwiftUI

/// "SPEED  1×": the speed of the prompter's bars as a multiple of the natural reading pace (`SpeedScale`), on the system's slider. It moves
/// from stop to stop, every 0.1× from 0.2× to 2× (the same stops as Settings › Prompter and the remote), and each stop it reaches is felt as a
/// light tick. The value is always written above the track, so the 19 stops need no marks of their own.
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
