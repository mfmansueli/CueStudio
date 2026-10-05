//
//  SkyStarsLayer.swift
//  Cue Studio
//

import SwiftUI

/// "Your stars" (v29 · L16): one small yellow star in the sky above Scripts for each idea sent, the 14 newest. They
/// twinkle slowly (4 s); still with Reduce Motion, in Low Power Mode and when the app is not active. The layer is
/// decoration: it never takes a touch and VoiceOver skips it.
struct SkyStarsLayer: View {
    let stars: [StarPoint]
    /// The star that has just arrived is drawn by the flight; the others twinkle.
    var isAnimated = true

    /// The band of the screen the stars live in, from its top edge: over the status bar and the bar's title row.
    static let band: ClosedRange<CGFloat> = 8...54

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let animates = isAnimated && !reduceMotion && scenePhase == .active && !ProcessInfo.processInfo.isLowPowerModeEnabled
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animates)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for (index, star) in stars.enumerated() {
                    let point = Self.position(of: star, in: size)
                    let phase = animates ? 0.65 + 0.35 * sin((time + Double(index) * 0.7) * 2 * .pi / 4) : 0.85
                    let glow = Path(ellipseIn: CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9))
                    context.fill(glow, with: .color(Palette.World.skyStarYou.opacity(0.22 * phase)))
                    let core = Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3))
                    context.fill(core, with: .color(Palette.World.skyStarYou.opacity(phase)))
                }
            }
        }
        .frame(height: Self.band.upperBound + 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func position(of star: StarPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: star.x * size.width, y: band.lowerBound + star.y * (band.upperBound - band.lowerBound))
    }
}
