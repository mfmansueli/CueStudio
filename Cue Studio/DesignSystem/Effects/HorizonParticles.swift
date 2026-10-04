//
//  HorizonParticles.swift
//  Cue Studio
//

import SwiftUI

/// Three tiny yellow and white specks that rise about 34 pt from the horizon and fade, each on its own cycle
/// (2.6 s, 3.1 s with a 0.8 s delay, 2.9 s with a 1.6 s delay). At most four are ever on screen, and none
/// under Reduce Motion.
struct HorizonParticles: View {
    /// The height the specks need above the line.
    static let reach: CGFloat = 48

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where along the line, how long a cycle takes, when it starts, and where it drifts to.
    private nonisolated struct Speck {
        let position: Double
        let period: Double
        let delay: Double
        let drift: CGSize
        let isYellow: Bool
    }

    private static let specks = [
        Speck(position: 0.18, period: 2.6, delay: 0, drift: CGSize(width: -6, height: -34), isYellow: true),
        Speck(position: 0.47, period: 3.1, delay: 0.8, drift: CGSize(width: 8, height: -40), isYellow: false),
        Speck(position: 0.76, period: 2.9, delay: 1.6, drift: CGSize(width: -6, height: -34), isYellow: true),
    ]

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                Canvas { canvas, size in
                    let time = context.date.timeIntervalSinceReferenceDate
                    for speck in Self.specks {
                        let cycle = ((time - speck.delay).truncatingRemainder(dividingBy: speck.period) + speck.period)
                            .truncatingRemainder(dividingBy: speck.period) / speck.period
                        let opacity = Self.opacity(at: cycle)
                        guard opacity > 0 else { continue }
                        let point = CGPoint(
                            x: size.width * speck.position + speck.drift.width * cycle,
                            y: size.height + speck.drift.height * cycle
                        )
                        let color = (speck.isYellow ? Palette.acc : Color.white).opacity(opacity)
                        canvas.fill(Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)), with: .color(color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 0 → 0.9 over the first fifth of the cycle, then back to 0.
    static func opacity(at cycle: Double) -> Double {
        cycle < 0.2 ? 0.9 * cycle / 0.2 : 0.9 * (1 - (cycle - 0.2) / 0.8)
    }
}
