//
//  UltraStarHop.swift
//  Cue Studio
//

import SwiftUI

/// The ✦ leaving the dock's invitation for the writer chip once Ultra AI is allowed (`UltraMotion`): it swells as it lifts off, arcs up and over as
/// the idea's star does, and shrinks into the chip, glowing all the way. Drawn over the dock, in its coordinate space; at rest (and once landed)
/// nothing shows. Each change of `trigger` flies it once.
struct UltraStarHop: View {
    let from: CGPoint
    let to: CGPoint
    let trigger: Int

    private struct Flight {
        var progress = 0.0
        var scale = 1.0
        var opacity = 0.0
        var glow = 0.0
    }

    var body: some View {
        let violet = Palette.aiText
        let from = from
        let to = to
        return Text(verbatim: "✦")
            .font(.fixed(14, weight: .bold))
            .foregroundStyle(Palette.aiTextStrong)
            .keyframeAnimator(initialValue: Flight(), trigger: trigger) { star, flight in
                star
                    .shadow(color: violet.opacity(flight.glow), radius: 9 * flight.glow)
                    .scaleEffect(flight.scale)
                    .opacity(flight.opacity)
                    .position(Self.point(from: from, to: to, at: flight.progress))
            } keyframes: { _ in
                let hop = UltraMotion.hop
                KeyframeTrack(\.progress) { CubicKeyframe(1, duration: hop) }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.7, duration: hop * 0.4)
                    CubicKeyframe(0.8, duration: hop * 0.6)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.04)
                    LinearKeyframe(1, duration: hop - 0.1)
                    LinearKeyframe(0, duration: 0.06)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(1, duration: 0.08)
                    LinearKeyframe(1, duration: hop - 0.08)
                    CubicKeyframe(0, duration: 0.2)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A quadratic arc that rises above the straight line between the two, leaning towards where it goes.
    nonisolated private static func point(from: CGPoint, to: CGPoint, at progress: Double) -> CGPoint {
        let control = CGPoint(x: (from.x + to.x) / 2 + (to.x - from.x) * 0.2, y: min(from.y, to.y) - 36)
        let rest = 1 - progress
        return CGPoint(
            x: rest * rest * from.x + 2 * rest * progress * control.x + progress * progress * to.x,
            y: rest * rest * from.y + 2 * rest * progress * control.y + progress * progress * to.y
        )
    }
}
