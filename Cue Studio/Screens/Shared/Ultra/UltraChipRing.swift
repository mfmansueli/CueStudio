//
//  UltraChipRing.swift
//  Cue Studio
//

import SwiftUI

/// The ring the writer chip sends out as it lights on Ultra AI (`UltraMotion.ring`): it leaves the chip's edge in violet and widens as it fades, never
/// over the chip's words. Each change of `trigger` sends one; at rest nothing shows.
struct UltraChipRing: View {
    let trigger: Int

    private struct Wave {
        var scale = 1.0
        var opacity = 0.0
    }

    var body: some View {
        Capsule()
            .strokeBorder(Palette.aiText, lineWidth: 1.5)
            .keyframeAnimator(initialValue: Wave(), trigger: trigger) { ring, wave in
                ring.scaleEffect(wave.scale).opacity(wave.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) { CubicKeyframe(1.6, duration: UltraMotion.ring) }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.9, duration: 0.05)
                    CubicKeyframe(0, duration: UltraMotion.ring - 0.05)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
