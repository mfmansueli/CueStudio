//
//  BestTakeSparkles.swift
//  Cue Studio
//

import SwiftUI

/// The burst around the star when a take is made the best (owner's refinement, 22/10/2026): five yellow sparks fly a few points out and fade
/// in about half a second, in time with `HapticPatterns.bestTake`. Nothing with Reduce Motion. Decorative.
struct BestTakeSparkles: View {
    /// Each change bursts once.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where each spark ends, in points from the star's centre.
    private static let ends: [CGSize] = [
        CGSize(width: -15, height: -13), CGSize(width: 15, height: -13), CGSize(width: -17, height: 9), CGSize(width: 17, height: 9),
        CGSize(width: 0, height: -19),
    ]

    var body: some View {
        KeyframeAnimator(initialValue: 0.0, trigger: trigger) { progress in
            Canvas { canvas, size in
                guard trigger > 0, !reduceMotion, progress > 0, progress < 1 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for end in Self.ends {
                    let radius = 2.2 * (1 - 0.6 * progress)
                    let spot = CGPoint(x: center.x + end.width * progress, y: center.y + end.height * progress)
                    canvas.fill(
                        Path(ellipseIn: CGRect(x: spot.x - radius, y: spot.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(Palette.acc.opacity(1 - progress))
                    )
                }
            }
            .frame(width: 44, height: 44)
        } keyframes: { _ in
            LinearKeyframe(0.0, duration: 0)
            CubicKeyframe(1.0, duration: 0.55)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
