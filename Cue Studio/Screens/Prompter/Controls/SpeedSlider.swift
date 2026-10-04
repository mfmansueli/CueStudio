//
//  SpeedSlider.swift
//  Cue Studio
//

import SwiftUI

/// "SPEED  0.7×": the compact orb pill of the prompter's controls (v27). A soft tick marks the natural pace
/// (150 words a minute); the value is always written.
struct SpeedSlider: View {
    let speed: Double
    let speedLabel: String
    let onChange: @MainActor @Sendable (Double) -> Void

    var body: some View {
        OrbSlider(
            value: Binding(get: { speed }, set: { onChange(PrompterSettings.clampedSpeed($0)) }),
            range: PrompterSettings.speedRange,
            defaultValue: ReadTime.naturalSpeed,
            style: .compact,
            label: String(localized: "Speed"),
            valueText: speedLabel,
            accessibilityIdentifier: "prompter.speedSlider"
        )
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    SpeedSlider(speed: 0.7, speedLabel: "0.7×", onChange: { _ in })
        .padding()
        .background(Color.black)
}
#endif
