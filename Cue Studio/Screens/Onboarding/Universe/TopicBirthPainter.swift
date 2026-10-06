//
//  TopicBirthPainter.swift
//  Cue Studio
//

import SwiftUI

/// Draws one topic's birth `age` seconds after the tap (`TopicBirth`): the burst on the chip, the light on its route with its tail, dots and
/// glints, and the landing in sparks, streaks, rings and a cross of light. Every moving part reads its pose from the board's layer.
struct TopicBirthPainter {
    let birth: TopicBirth
    let age: Double

    private var light: Color { birth.color.mix(with: .white, by: 0.65) }
    private var pale: Color { birth.color.mix(with: .white, by: 0.8) }

    func paint(in context: inout GraphicsContext) {
        chip(in: &context)
        route(in: &context)
        landing(in: &context)
    }

    private func pose(_ layer: String) -> MotionPose { TopicBirth.pose(layer, at: age) }

    // MARK: - On the chip

    private func chip(in context: inout GraphicsContext) {
        let centre = birth.from
        let ring = pose(TopicBirth.chipRing)
        if ring.opacity > 0.01 {
            context.stroke(circle(centre, 17 * ring.sx), with: .color(birth.color.opacity(ring.opacity)), lineWidth: 1.5)
        }
        cross(at: centre, size: 52, pose: pose(TopicBirth.chipCross), in: &context)
        let sizes: [CGFloat] = [3, 2, 2.5]
        for (index, layer) in TopicBirth.chipSparks.enumerated() {
            spark(pose(layer), at: centre, size: sizes[index % 3], color: [light, .white, birth.color][index % 3], in: &context)
        }
    }

    // MARK: - On the way

    private func route(in context: inout GraphicsContext) {
        let line = pose(TopicBirth.routeLine)
        if line.opacity > 0.01 {
            // A line that draws with the light (pink to white) and dissolves 0.9 s after it lands.
            context.drawLayer { layer in
                layer.opacity = line.opacity
                layer.addFilter(.shadow(color: birth.color.opacity(0.7), radius: 3))
                layer.stroke(
                    birth.path.trimmedPath(from: 0, to: line.drawn),
                    with: .linearGradient(Gradient(colors: [birth.color, .white]), startPoint: birth.from, endPoint: birth.to),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
            }

        }
        let tail = pose(TopicBirth.routeTail)
        if tail.opacity > 0.01, let dash = tail.dash {
            let start = max(0, -dash / 100)
            let end = min(1, (-dash + 16) / 100)
            if end > start {
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: birth.color.opacity(0.9), radius: 4))
                    layer.stroke(
                        birth.path.trimmedPath(from: start, to: end), with: .color(birth.color.opacity(tail.opacity)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
            }
        }
        glints(in: &context)
        head(in: &context)
    }

    /// The light itself: a glow with a hot core, and the eight dots that follow it a little later each (5 to 18 pt, fainter and fainter).
    private func head(in context: inout GraphicsContext) {
        let sizes: [CGFloat] = [18, 15, 13, 11, 9, 7, 6, 5]
        for (index, layer) in TopicBirth.followers.enumerated().reversed() {
            let follower = pose(layer)
            guard follower.opacity > 0.01, let along = follower.along else { continue }
            let at = point(onRouteAt: along)
            let fade = 0.85 - Double(index) * 0.1
            context.fill(circle(at, sizes[index] / 2 * 0.6), with: .color(light.opacity(follower.opacity * fade)))
        }
        let head = pose(TopicBirth.head)
        let hot = Palette.flightHot
        guard head.opacity > 0.01, let along = head.along else { return }
        let point = point(onRouteAt: along)
        context.fill(
            circle(point, 14),
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

    private func glints(in context: inout GraphicsContext) {
        for glint in TopicBirth.glints {
            let glow = pose(glint.layer)
            cross(
                at: birth.point(at: glint.along), size: glint.size, thickness: 1, pose: glow, tint: Palette.starWarm, glows: false, in: &context
            )
        }
    }

    // MARK: - The landing

    private func landing(in context: inout GraphicsContext) {
        let centre = birth.to
        let sizes: [CGFloat] = [3, 2, 2.5]
        for (index, layer) in TopicBirth.landingSparks.enumerated() {
            spark(pose(layer), at: centre, size: sizes[index % 3], color: [light, .white, birth.color][index % 3], in: &context)
        }
        for layer in TopicBirth.streaks { streak(pose(layer), at: centre, in: &context) }
        let rings: [(radius: CGFloat, color: Color, width: CGFloat)] = [
            (20, birth.color, 1.5), (20, birth.color.mix(with: .white, by: 0.85).opacity(0.8), 1), (30, pale.opacity(0.9), 1),
        ]
        for (layer, ring) in zip(TopicBirth.rings, rings) {
            let pose = pose(layer)
            guard pose.opacity > 0.01 else { continue }
            context.stroke(circle(centre, ring.radius * pose.sx), with: .color(ring.color.opacity(pose.opacity)), lineWidth: ring.width)
        }
        cross(at: centre, size: 70, pose: pose(TopicBirth.landingCross), in: &context)
    }

    // MARK: - Shapes

    private func spark(_ pose: MotionPose, at centre: CGPoint, size: CGFloat, color: Color, in context: inout GraphicsContext) {
        LightFX.spark(pose, at: centre, size: size, color: color, in: &context)
    }

    private func streak(_ pose: MotionPose, at centre: CGPoint, in context: inout GraphicsContext) {
        LightFX.streak(pose, at: centre, from: birth.color, in: &context)
    }

    private func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path { LightFX.disc(centre, radius) }

    /// A cross of light in the topic's colour, `size` across.
    private func cross(
        at centre: CGPoint, size: CGFloat, thickness: CGFloat = 1.8, pose: MotionPose, tint: Color? = nil, glows: Bool = true,
        in context: inout GraphicsContext
    ) {
        LightFX.cross(
            at: centre, size: size, thickness: thickness, pose: pose, color: tint ?? birth.color.mix(with: .white, by: 0.7),
            glow: glows ? birth.color.opacity(0.9) : nil, in: &context
        )
    }
}
