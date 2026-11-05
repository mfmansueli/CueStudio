//
//  InviteOrbit.swift
//  Cue Studio
//

import SwiftUI

/// The invites' picture: the creator's core in their light, and around it one tilted orbit with a place for each friend who can earn a reward.
/// A friend whose first export counted is a lit planet (yellow, violet for Ultra AI's scripts); the places still open are dashed. The orbit
/// turns slowly, planets passing behind the core and in front of it, under a few twinkling stars. Reduce Motion: at rest. Decorative (the line
/// under it says the count).
struct InviteOrbit: View {
    let friends: Int
    let limit: Int
    let core: CoreColor
    let planet: Color

    static let size = CGSize(width: 260, height: 156)
    /// Seconds for the orbit to go round.
    private static let lap = 60.0
    /// Fixed places of the stars, as fractions of the picture, and their twinkle's phase.
    private static let stars: [(x: Double, y: Double, phase: Double)] = [
        (0.06, 0.18, 0.1), (0.15, 0.72, 1.3), (0.24, 0.08, 2.2), (0.33, 0.9, 0.7), (0.71, 0.06, 1.9), (0.8, 0.84, 0.4),
        (0.9, 0.22, 2.7), (0.96, 0.62, 1.1), (0.52, 0.02, 3.0), (0.44, 0.97, 2.5), (0.02, 0.48, 1.6), (0.62, 0.94, 0.2),
    ]

    var body: some View {
        AmbientTimeline { ambient in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: ambient.seconds)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    private struct Place {
        let point: CGPoint
        /// -1 at the back of the orbit, 1 at the front.
        let depth: Double
        let isLit: Bool
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for star in Self.stars {
            let twinkle = 0.5 + 0.5 * sin(time * 1.3 + star.phase * 2.4)
            let spot = CGRect(x: star.x * size.width - 0.9, y: star.y * size.height - 0.9, width: 1.8, height: 1.8)
            canvas.fill(Path(ellipseIn: spot), with: .color(Palette.ink.opacity(0.18 + 0.32 * twinkle)))
        }
        let radii = CGSize(width: size.width * 0.44, height: size.height * 0.3)
        let ring = Path(ellipseIn: CGRect(x: center.x - radii.width, y: center.y - radii.height, width: radii.width * 2, height: radii.height * 2))
        canvas.stroke(ring, with: .color(Palette.ink.opacity(0.12)), lineWidth: 1)
        let turn = time / Self.lap * 2 * .pi
        let places = (0..<max(1, limit)).map { index -> Place in
            let angle = -Double.pi / 2 + 2 * .pi * Double(index) / Double(max(1, limit)) + turn
            return Place(
                point: CGPoint(x: center.x + radii.width * cos(angle), y: center.y + radii.height * sin(angle)),
                depth: sin(angle), isLit: index < friends
            )
        }
        for place in places where place.depth < 0 { drawPlace(place, in: &canvas) }
        drawCore(in: &canvas, center: center, time: time)
        for place in places where place.depth >= 0 { drawPlace(place, in: &canvas) }
    }

    /// A friend's place: a lit planet with its glow, or a dashed ring; smaller and dimmer at the back.
    private func drawPlace(_ place: Place, in canvas: inout GraphicsContext) {
        let scale = 0.72 + 0.28 * (place.depth + 1) / 2
        let radius = 9 * scale
        let box = CGRect(x: place.point.x - radius, y: place.point.y - radius, width: radius * 2, height: radius * 2)
        guard place.isLit else {
            canvas.stroke(
                Path(ellipseIn: box), with: .color(Palette.ink.opacity(0.22 + 0.18 * scale)), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5])
            )
            return
        }
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: planet.opacity(0.8), radius: 9))
            layer.fill(Path(ellipseIn: box), with: .color(planet.opacity(0.55 + 0.45 * scale)))
        }
        let shine = CGRect(x: box.minX + radius * 0.45, y: box.minY + radius * 0.4, width: radius * 0.55, height: radius * 0.55)
        canvas.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.7)))
    }

    /// The creator's core: its halo breathing every 3.6 s, the ball lit from the top left in its four stops.
    private func drawCore(in canvas: inout GraphicsContext, center: CGPoint, time: Double) {
        let breath = (1 + sin(time / 3.6 * 2 * .pi)) / 2
        let glow = Color(hex: core.glow.hex)
        let halo = 40 + 8 * breath
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [glow.opacity(core.glow.opacity * (0.75 + 0.25 * breath)), glow.opacity(0)]),
                center: center, startRadius: 0, endRadius: halo
            )
        )
        let stops = core.stops
        let ball = CGRect(x: center.x - 19, y: center.y - 19, width: 38, height: 38)
        canvas.fill(Path(ellipseIn: ball), with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hex: stops.highlight), location: 0),
                .init(color: Color(hex: stops.light), location: 0.3),
                .init(color: Color(hex: stops.body), location: 0.62),
                .init(color: Color(hex: stops.edge), location: 1),
            ]),
            center: CGPoint(x: ball.minX + ball.width * 0.38, y: ball.minY + ball.height * 0.34), startRadius: 0, endRadius: 26
        ))
    }
}
