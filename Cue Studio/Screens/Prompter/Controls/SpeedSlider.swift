//
//  SpeedSlider.swift
//  Cue Studio
//

import SwiftUI

/// Steady mode's speed in the toolbar: "SPEED", the v26 slider (0.3× to 2.0×) and the value in
/// yellow, on a faint 44 pt capsule.
struct SpeedSlider: View {
    let speed: Double
    let speedLabel: String
    let onChange: @MainActor @Sendable (Double) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("SPEED")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Palette.ink2)
                .fixedSize()
                .accessibilityHidden(true)
            CueSlider(
                title: String(localized: "Speed"), value: speed, range: PrompterSettings.speedRange, step: 0.1,
                valueText: speedLabel, identifier: "prompter.speedSlider", onChange: { onChange($0) }
            )
            .padding(.horizontal, 6)
            Text(speedLabel)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.accText)
                .fixedSize()
                .accessibilityHidden(true)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
        .background(Palette.overlayFill.opacity(0.6), in: Capsule())
    }
}

#if DEBUG
#Preview {
    SpeedSlider(speed: 0.7, speedLabel: "0.7×", onChange: { _ in })
        .padding()
        .background(Color.black)
}
#endif
