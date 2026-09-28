//
//  SpeedSlider.swift
//  Cue Studio
//

import SwiftUI

/// Steady mode's speed in the Selfie toolbar: the value, then a compact slider from 0.3× to 2.0×.
struct SpeedSlider: View {
    let speed: Double
    let speedLabel: String
    let onChange: @MainActor @Sendable (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(speedLabel)
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                Text("SPEED")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(width: 36, alignment: .leading)
            .accessibilityHidden(true)
            Slider(value: Binding(get: { speed }, set: onChange), in: PrompterSettings.speedRange, step: 0.1)
                .tint(Palette.acc)
                .accessibilityLabel(Text("Speed"))
                .accessibilityValue(Text(speedLabel))
                .accessibilityIdentifier("prompter.speedSlider")
        }
        .foregroundStyle(.white)
        .padding(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 16))
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Palette.overlayFill, in: Capsule())
    }
}

#if DEBUG
#Preview {
    SpeedSlider(speed: 0.7, speedLabel: "0.7×", onChange: { _ in })
        .padding()
        .background(Color.black)
}
#endif
