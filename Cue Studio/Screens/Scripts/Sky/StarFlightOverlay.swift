//
//  StarFlightOverlay.swift
//  Cue Studio
//

import SwiftUI

/// The star of an idea sent, rising from the arrow to its place in the sky (760 ms along a curve, shrinking to 55%, with
/// a short trail), then a four-point glint that fades and turns (380 ms). It is the reward for sending, so it is the
/// loudest thing on the screen for a second and never repeats for the same idea. With Reduce Motion there is no
/// flight (`SkyMemory.launchStar` just waits a beat).
struct StarFlightOverlay: View {
    let flight: SkyMemory.StarFlight?

    @State private var progress: CGFloat = 0
    @State private var glintShown = false

    var body: some View {
        GeometryReader { proxy in
            if let flight {
                // The flight is told in screen coordinates; this layer starts wherever its screen frame does.
                let origin = proxy.frame(in: .global).origin
                let start = CGPoint(x: flight.from.x - origin.x, y: flight.from.y - origin.y)
                let target = SkyStarsLayer.position(of: flight.to, in: proxy.size)
                let control = CGPoint(
                    x: (start.x + target.x) / 2 + (target.x > start.x ? -60 : 60),
                    y: min(start.y, target.y) - 40
                )
                ZStack(alignment: .topLeading) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(Palette.World.skyStarYou.opacity(0.7 - Double(index) * 0.1))
                            .frame(width: 3, height: 3)
                            .modifier(FlightPath(progress: progress, lag: CGFloat(index + 1) * 0.07, from: start, control: control, to: target))
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                        .shadow(color: Palette.World.skyStarYouGlow, radius: 6)
                        .scaleEffect(1 - progress * 0.45)
                        .modifier(FlightPath(progress: progress, lag: 0, from: start, control: control, to: target))
                        .opacity(progress < 1 ? 1 : 0)
                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Palette.World.skyStarYou)
                        .scaleEffect(glintShown ? 0.4 : 1)
                        .rotationEffect(.degrees(glintShown ? 45 : 0))
                        .opacity(progress >= 1 ? (glintShown ? 0 : 1) : 0)
                        .modifier(FlightPath(progress: 1, lag: 0, from: start, control: control, to: target))
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .onAppear { fly() }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fly() {
        progress = 0
        glintShown = false
        withAnimation(.timingCurve(0.35, 0.1, 0.25, 1, duration: 0.76)) { progress = 1 }
        withAnimation(.easeOut(duration: 0.5).delay(0.76)) { glintShown = true }
    }

    /// Moves a view along the curve as `progress` goes from 0 to 1 (a `GeometryEffect`, so the animation follows the
    /// curve and not the straight line between the ends). `lag` holds it back, for the trail.
    private struct FlightPath: GeometryEffect {
        var progress: CGFloat
        let lag: CGFloat
        let from: CGPoint
        let control: CGPoint
        let to: CGPoint

        var animatableData: CGFloat {
            get { progress }
            set { progress = newValue }
        }

        func effectValue(size: CGSize) -> ProjectionTransform {
            let spot = StarFlightOverlay.point(at: max(0, progress - lag), from: from, control: control, to: to)
            return ProjectionTransform(CGAffineTransform(translationX: spot.x - size.width / 2, y: spot.y - size.height / 2))
        }
    }

    /// A point on the quadratic curve from `from` to `to` bending toward `control` (`t` from 0 to 1).
    static func point(at t: CGFloat, from: CGPoint, control: CGPoint, to: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
            y: u * u * from.y + 2 * u * t * control.y + t * t * to.y
        )
    }
}
