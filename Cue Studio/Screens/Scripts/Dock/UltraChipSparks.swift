//
//  UltraChipSparks.swift
//  Cue Studio
//

import SwiftUI

/// The writer chip's ✦ lighting on Ultra AI: six small four-point stars fly out of it in Cue's violet, lilac and yellow, turning as they go,
/// and fade in about 0.6 s, a glint on the Taptic Engine for the first ones (`HapticPatterns.ultraIgnite`). Drawn round the ✦ (44 × 44, centred
/// on it), over the chip and past it. Each change of `trigger` bursts once; nothing with Reduce Motion. Decorative.
struct UltraChipSparks: View {
    let trigger: Int

    /// How long the sparks fly.
    nonisolated static let duration = 0.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where each spark ends, in points from the ✦, how big it is at the start, and its colour.
    private static let sparks: [(end: CGSize, size: CGFloat, color: Color)] = [
        (CGSize(width: -14, height: -15), 4.5, Palette.aiTextStrong),
        (CGSize(width: 13, height: -17), 5.5, Palette.accText),
        (CGSize(width: 22, height: -3), 4, Palette.aiText),
        (CGSize(width: 15, height: 15), 5, Palette.aiTextStrong),
        (CGSize(width: -10, height: 16), 4, Palette.accText),
        (CGSize(width: -20, height: 1), 3.5, Palette.aiText),
    ]

    var body: some View {
        let showing = trigger > 0 && !reduceMotion
        let sparks = Self.sparks
        return KeyframeAnimator(initialValue: 0.0, trigger: trigger) { progress in
            Canvas { canvas, size in
                guard showing, progress > 0, progress < 1 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // Out fast, then slowing; small and gone by the end.
                let travel = 1 - pow(1 - progress, 3)
                for spark in sparks {
                    let spot = CGPoint(x: center.x + spark.end.width * travel, y: center.y + spark.end.height * travel)
                    let radius = spark.size * (1 - 0.7 * progress)
                    canvas.fill(
                        SparkShape.path(center: spot, radius: radius, turn: .degrees(90 * progress)),
                        with: .color(spark.color.opacity(1 - progress))
                    )
                }
            }
            .frame(width: 44, height: 44)
        } keyframes: { _ in
            LinearKeyframe(0.0, duration: 0)
            LinearKeyframe(1.0, duration: Self.duration)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
