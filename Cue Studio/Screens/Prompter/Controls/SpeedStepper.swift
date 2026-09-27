//
//  SpeedStepper.swift
//  Cue Studio
//

import SwiftUI

/// − 1.0× + control for Selfie mode.
struct SpeedStepper: View {
    let speedLabel: String
    let onSlower: () -> Void
    let onFaster: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSlower) {
                Image(systemName: "minus").frame(width: 40, height: 44)
            }
            .accessibilityLabel(Text("Slower"))
            VStack(spacing: 3) {
                Text(speedLabel)
                    .font(.body.weight(.semibold).monospacedDigit())
                Text("SPEED")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.7)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(width: 60)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Speed"))
            .accessibilityValue(Text(speedLabel))
            Button(action: onFaster) {
                Image(systemName: "plus").frame(width: 40, height: 44)
            }
            .accessibilityLabel(Text("Faster"))
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .background(Palette.overlayFill, in: Capsule())
    }
}

#if DEBUG
#Preview {
    SpeedStepper(speedLabel: "1.0×", onSlower: {}, onFaster: {})
        .padding()
        .background(Color.black)
}
#endif
