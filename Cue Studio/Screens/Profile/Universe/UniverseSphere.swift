//
//  UniverseSphere.swift
//  Cue Studio
//

import SwiftUI

/// The core of 9.2 as the prototype shows it in motion: "YOU" is a lit sphere of the core's colour, 38 pt, lifted over the middle of the disc, with a warm
/// glow that swells (6 s) and two thin rings tilted around it, each carrying a small bead of a world's colour (31 and 40 s a lap). The far half of each ring
/// goes behind the ball and the near half in front, so the picture has depth. Drawn in board points; the map's disc of videos turns around it.
enum UniverseSphere {
    static let diameter: CGFloat = 38
    static let breathPeriod = 6.0

    /// One tilted ring: its radii, its tilt in degrees, the world colour of its bead, the seconds a lap takes and where the bead starts (degrees).
    private struct Ring {
        let rx: CGFloat
        let ry: CGFloat
        let tilt: Double
        let bead: Color
        let period: Double
        let start: Double
    }

    private static let rings = [
        Ring(rx: 33, ry: 12, tilt: -14, bead: Palette.World.pink, period: 40, start: 280),
        Ring(rx: 27, ry: 9, tilt: 16, bead: Palette.World.mint, period: 31, start: 20),
    ]

    /// The swell of the ball and the glow, 0 → 1 → 0 over six seconds, eased.
    static func swell(at time: Double) -> Double { 0.5 - 0.5 * cos(time * 2 * .pi / breathPeriod) }

    /// The glow: a soft halo of the core colour, reaching 50 pt, a little under half the strength the core's colour names, at .78 ↔ 1 as it swells.
    static func drawGlow(_ canvas: inout GraphicsContext, at center: CGPoint, color: CoreColor, swell: Double) {
        let glow = Color(hex: color.glow.hex, opacity: color.glow.opacity * 0.5)
        canvas.opacity = 0.78 + 0.22 * swell
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - 50, y: center.y - 50, width: 100, height: 100)),
            with: .radialGradient(Gradient(colors: [glow, glow.opacity(0)]), center: center, startRadius: 0, endRadius: 50)
        )
        canvas.opacity = 1
    }

    /// The far halves of the rings and their beads that are behind the ball.
    static func drawBack(_ canvas: inout GraphicsContext, at center: CGPoint, time: Double) {
        for ring in rings { draw(ring, in: &canvas, at: center, time: time, front: false) }
    }

    /// The ball: `radial-gradient(circle at 38% 34%, highlight, light 30%, body 62%, edge)` with a thin dark rim.
    static func drawBall(_ canvas: inout GraphicsContext, at center: CGPoint, color: CoreColor, swell: Double) {
        let stops = color.stops
        let radius = diameter / 2 * (1 + 0.04 * swell)
        let size = radius * 2
        let highlight = CGPoint(x: center.x - radius + 0.38 * size, y: center.y - radius + 0.34 * size)
        let ball = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: size, height: size))
        canvas.fill(
            ball,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: stops.highlight), location: 0), .init(color: Color(hex: stops.light), location: 0.30),
                    .init(color: Color(hex: stops.body), location: 0.62), .init(color: Color(hex: stops.edge), location: 1),
                ]),
                center: highlight, startRadius: 0, endRadius: size * 0.8
            )
        )
        // The shadow side: the far lower right goes darker, so it reads as a ball and not a disc.
        canvas.fill(
            ball,
            with: .radialGradient(
                Gradient(colors: [.clear, Color.black.opacity(0.32)]),
                center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.35), startRadius: radius * 0.5, endRadius: radius * 1.5
            )
        )
        canvas.stroke(ball, with: .color(Palette.Universe.coreRim), lineWidth: 1)
    }

    /// The map's YOU as a real body (not the small cores'): soft bands of atmosphere along its tilt, two faint storms that turn with it (a lap in
    /// 36 s), going narrow toward the edge as they turn away, the limb darkening, a soft specular light and a fine line of air round it. `time` nil
    /// holds it still.
    static func drawSurface(_ canvas: inout GraphicsContext, at center: CGPoint, color: CoreColor, swell: Double, time: Double?) {
        let stops = color.stops
        let radius = diameter / 2 * (1 + 0.04 * swell)
        let ball = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        canvas.drawLayer { surface in
            surface.clip(to: ball)
            surface.translateBy(x: center.x, y: center.y)
            surface.rotate(by: .degrees(-14))
            // Bands: lighter and darker belts, soft at their edges.
            let bands: [(y: CGFloat, height: CGFloat, color: UInt32, opacity: Double)] = [
                (-0.62, 0.18, stops.edge, 0.12), (-0.18, 0.14, stops.edge, 0.1), (0.14, 0.24, stops.light, 0.1), (0.5, 0.16, stops.edge, 0.13),
            ]
            for band in bands {
                let rect = CGRect(x: -radius, y: radius * band.y, width: radius * 2, height: radius * band.height)
                let tone = Color(hex: band.color)
                surface.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [tone.opacity(0), tone.opacity(band.opacity), tone.opacity(0)]),
                        startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
                    )
                )
            }
            // Storms that turn with the sphere: across the face, narrowing toward the limb, hidden on the far side.
            let turn = (time ?? 0) / 36 * 2 * .pi
            let storms: [(latitude: Double, longitude: Double, size: CGFloat)] = [(-0.3, 0.4, 0.22), (0.3, 3.2, 0.16)]
            for storm in storms {
                let longitude = storm.longitude + turn
                let facing = cos(longitude)
                guard facing > 0.05 else { continue }
                let across = sqrt(max(0, 1 - storm.latitude * storm.latitude))
                let x = radius * across * sin(longitude)
                let y = radius * storm.latitude
                let width = radius * storm.size * facing
                let height = radius * storm.size * 0.55
                let oval = Path(ellipseIn: CGRect(x: x - width, y: y - height, width: width * 2, height: height * 2))
                surface.fill(
                    oval,
                    with: .radialGradient(
                        Gradient(colors: [Color(hex: stops.edge).opacity(0.22 * facing), Color(hex: stops.body).opacity(0.08 * facing), .clear]),
                        center: CGPoint(x: x, y: y), startRadius: 0, endRadius: max(width, height)
                    )
                )
            }
        }
        // The limb darkens, the light falls soft on the lit side, and a thin halo of air holds the ball.
        canvas.fill(
            ball,
            with: .radialGradient(
                Gradient(stops: [.init(color: .clear, location: 0.62), .init(color: .black.opacity(0.28), location: 1)]),
                center: center, startRadius: 0, endRadius: radius
            )
        )
        let shine = CGPoint(x: center.x - radius * 0.36, y: center.y - radius * 0.4)
        canvas.fill(
            Path(ellipseIn: CGRect(x: shine.x - radius * 0.34, y: shine.y - radius * 0.24, width: radius * 0.68, height: radius * 0.48)),
            with: .radialGradient(Gradient(colors: [.white.opacity(0.3), .white.opacity(0)]), center: shine, startRadius: 0, endRadius: radius * 0.34)
        )
        canvas.stroke(
            Path(ellipseIn: CGRect(x: center.x - radius - 0.8, y: center.y - radius - 0.8, width: (radius + 0.8) * 2, height: (radius + 0.8) * 2)),
            with: .color(Color(hex: stops.highlight).opacity(0.28)), lineWidth: 0.7
        )
    }

    /// The near halves of the rings and their beads that are in front of the ball.
    static func drawFront(_ canvas: inout GraphicsContext, at center: CGPoint, time: Double) {
        for ring in rings { draw(ring, in: &canvas, at: center, time: time, front: true) }
    }

    private static func draw(_ ring: Ring, in canvas: inout GraphicsContext, at center: CGPoint, time: Double, front: Bool) {
        var layer = canvas
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .degrees(ring.tilt))
        var arc = Path()
        arc.addArc(center: .zero, radius: 1, startAngle: .degrees(front ? 0 : 180), endAngle: .degrees(front ? 180 : 360), clockwise: false)
        layer.stroke(
            arc.applying(CGAffineTransform(scaleX: ring.rx, y: ring.ry)),
            with: .color(Palette.Universe.starGold.opacity(front ? 0.55 : 0.3)), lineWidth: 0.8
        )
        let angle = (ring.start + 360 * time / ring.period) * .pi / 180
        guard (sin(angle) >= 0) == front else { return }
        let bead = CGPoint(x: ring.rx * cos(angle), y: ring.ry * sin(angle))
        layer.fill(
            Path(ellipseIn: CGRect(x: bead.x - 2.3, y: bead.y - 2.3, width: 4.6, height: 4.6)),
            with: .color(ring.bead.opacity(front ? 1 : 0.6))
        )
    }
}
