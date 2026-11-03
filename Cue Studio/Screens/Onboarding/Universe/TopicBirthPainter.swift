//
//  TopicBirthPainter.swift
//  Cue Studio
//

import SwiftUI

/// Draws one topic's birth `age` seconds after the tap (`TopicBirth`): a ring opening on the chip, the light flying its curve with a short
/// tail, and a ring where it lands on the orbit. Kept to that on purpose (owner, 02/11/2026: few trails, as on 1.1); every moving part reads
/// its pose from the board's layer.
struct TopicBirthPainter {
    let birth: TopicBirth
    let age: Double

    private var light: Color { birth.color.mix(with: .white, by: 0.65) }

    func paint(in context: inout GraphicsContext) {
        let ring = pose(TopicBirth.chipRing)
        if ring.opacity > 0.01 {
            context.stroke(LightFX.disc(birth.from, 17 * ring.sx), with: .color(birth.color.opacity(ring.opacity)), lineWidth: 1.2)
        }
        head(in: &context)
        let landing = pose(TopicBirth.landingRing)
        if landing.opacity > 0.01 {
            context.stroke(LightFX.disc(birth.to, 20 * landing.sx), with: .color(birth.color.opacity(landing.opacity)), lineWidth: 1.2)
        }
    }

    private func pose(_ layer: String) -> MotionPose { TopicBirth.pose(layer, at: age) }

    /// The light itself: 1.1's trail (`StarRibbon`, as short as 1.1's) in the topic's colours along the route, and a glow with a hot core.
    private func head(in context: inout GraphicsContext) {
        let trail = StarRibbon.trail(at: age, length: 0.2) { second in
            let pose = TopicBirth.pose(TopicBirth.head, at: second)
            guard let along = pose.along else { return (birth.from, 0) }
            return (point(onRouteAt: along), pose.opacity)
        }
        StarRibbon.draw(trail, colors: [.white, light, birth.color], width: 3.2, in: &context)
        let head = pose(TopicBirth.head)
        let hot = Palette.Flight.hot
        guard head.opacity > 0.01, let along = head.along else { return }
        let point = point(onRouteAt: along)
        context.fill(
            LightFX.disc(point, 14),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: hot.opacity(head.opacity), location: 0), .init(color: hot.opacity(head.opacity), location: 0.16 / 0.7),
                    .init(color: birth.color.opacity(0.6 * head.opacity), location: 0.32 / 0.7), .init(color: birth.color.opacity(0), location: 1),
                ]),
                center: point, startRadius: 0, endRadius: 14
            )
        )
    }

    /// Where a thing `fraction` of the way along the route's length is.
    private func point(onRouteAt fraction: Double) -> CGPoint {
        birth.path.trimmedPath(from: 0, to: min(max(fraction, 0.0001), 1)).currentPoint ?? birth.from
    }
}
