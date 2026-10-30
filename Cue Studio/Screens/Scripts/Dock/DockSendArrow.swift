//
//  DockSendArrow.swift
//  Cue Studio
//

import SwiftUI

/// The dock's send arrow (40 pt): yellow with a dark arrow, or, while Ultra AI writes the next idea, Ultra AI's: violet, a white arrow, Cue's
/// violet and gold going slowly round it (`UltraSendRim`). The violet spreads from the middle, where the writer chip's ✦ lands, and draws
/// back into it: the two colours are never mixed (a crossfade went through grey, seen on film 29/10/2026); under Reduce Motion they fade.
/// Each `charge` pops it and sends a ring out (`UltraChipRing`).
struct DockSendArrow: View {
    let isUltra: Bool
    let isEnabled: Bool
    /// The rim goes round: nothing covers the dock.
    let isRunning: Bool
    let charge: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fill: CGFloat = isUltra || reduceMotion ? 1 : 0.001
        let shown: Double = isUltra || !reduceMotion ? 1 : 0
        ZStack {
            face(Palette.acc, ink: Palette.accInk)
                .mask {
                    Rectangle()
                        .overlay { Circle().padding(-2).scaleEffect(fill).opacity(shown).blendMode(.destinationOut) }
                        .compositingGroup()
                }
            face(Palette.Scripts.ultraSend, ink: Palette.Scripts.ultraSendInk)
                .mask { Circle().padding(-2).scaleEffect(fill).opacity(shown) }
        }
        .overlay {
            if isUltra { UltraSendRim(isRunning: isRunning).transition(.opacity) }
        }
        .overlay { UltraChipRing(trigger: charge) }
        .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? 0 : charge) { arrow, scale in
            arrow.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.18, duration: 0.12, spring: .snappy)
            SpringKeyframe(1, duration: 0.45, spring: .bouncy)
        }
    }

    /// The arrow in one colour: its circle and its arrow.
    private func face(_ fill: Color, ink: Color) -> some View {
        Image(systemName: "arrow.up")
            .font(.fixed(17, weight: .bold))
            .foregroundStyle(ink)
            .frame(width: 40, height: 40)
            .background(fill.opacity(isEnabled ? 1 : 0.35), in: Circle())
    }
}
