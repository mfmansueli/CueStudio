//
//  PlanetPainter.swift
//  Cue Studio
//

import SwiftUI

/// A platform's planet on the universe map (9.2): a crisp sphere lit by YOU (`light` points from the planet toward the core), its day side bright,
/// its night side falling into shadow past a soft terminator, a line of atmosphere along the lit edge, faint belts and two storms that turn slowly
/// with it (a lap in 48 s; `time` nil holds them), with the details it earns: a glow at 52 videos, a thin ring at 156 and a small moon at 365
/// (`PlanetSize`); born white-hot on the opening (`white`). Drawn in board points.
enum PlanetPainter {
    /// How far its label sits from the planet's centre along x: 6 pt beyond the planet, or beyond the ring when there is one.
    static func labelDistance(diameter: CGFloat, detail: PlanetSize.Detail) -> CGFloat {
        let radius = diameter / 2
        return (detail >= .ring ? radius * 1.55 : radius) + 6
    }

    /// One planet's look besides its place and size: its tint, how faded, the flash of a new detail, how white it still is, where its light
    /// comes from (a unit vector toward YOU) and the second its surface has turned to.
    struct Look {
        var tint: Color
        var opacity: Double = 1
        var flash: Double = 0
        var white: Double = 0
        var light = CGVector(dx: -0.6, dy: -0.8)
        var time: Double?
    }

    static func draw(
        in canvas: inout GraphicsContext, center: CGPoint, diameter: CGFloat, detail: PlanetSize.Detail, tint: Color, opacity: Double = 1, flash: Double = 0,
        white: Double = 0
    ) {
        draw(in: &canvas, center: center, diameter: diameter, detail: detail, look: Look(tint: tint, opacity: opacity, flash: flash, white: white))
    }

    static func draw(in canvas: inout GraphicsContext, center: CGPoint, diameter: CGFloat, detail: PlanetSize.Detail, look: Look) {
        guard diameter > 0 else { return }
        let tint = look.tint
        let faded = canvas.opacity
        canvas.opacity = faded * look.opacity
        defer { canvas.opacity = faded }
        let radius = diameter / 2
        let light = look.light
        let halo = detail >= .glow ? radius * 2.2 : radius * 1.6
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(detail >= .glow ? 0.36 : 0.2), tint.opacity(0)]),
                center: CGPoint(x: center.x + light.dx * radius * 0.3, y: center.y + light.dy * radius * 0.3), startRadius: radius * 0.6, endRadius: halo
            )
        )
        if detail >= .ring { drawRing(in: &canvas, center: center, radius: radius, tint: tint, front: false) }
        let sphere = CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter)
        let ball = Path(ellipseIn: sphere)
        let lit = CGPoint(x: center.x + light.dx * radius * 0.42, y: center.y + light.dy * radius * 0.42)
        canvas.fill(
            ball,
            with: .radialGradient(
                Gradient(colors: [tint.mix(with: .white, by: 0.5), tint, tint.mix(with: .black, by: 0.4)]),
                center: lit, startRadius: 0, endRadius: radius * 1.5
            )
        )
        drawSurface(in: &canvas, ball: ball, center: center, radius: radius, look: look)
        // The night side: past a soft terminator, away from YOU.
        canvas.fill(
            ball,
            with: .linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0.42), .init(color: .black.opacity(0.5), location: 1)]),
                startPoint: CGPoint(x: center.x + light.dx * radius, y: center.y + light.dy * radius),
                endPoint: CGPoint(x: center.x - light.dx * radius, y: center.y - light.dy * radius)
            )
        )
        // A line of atmosphere along the lit edge, gone toward the night.
        canvas.stroke(
            Path(ellipseIn: sphere.insetBy(dx: -0.5, dy: -0.5)),
            with: .linearGradient(
                Gradient(colors: [tint.mix(with: .white, by: 0.6).opacity(0.8), tint.opacity(0)]),
                startPoint: CGPoint(x: center.x + light.dx * radius, y: center.y + light.dy * radius),
                endPoint: center
            ),
            lineWidth: max(0.6, radius * 0.09)
        )
        if look.white > 0.01 {
            canvas.drawLayer { hot in
                hot.addFilter(.shadow(color: .white.opacity(look.white), radius: radius))
                hot.fill(ball, with: .color(.white.opacity(look.white)))
            }
        }
        if detail >= .ring { drawRing(in: &canvas, center: center, radius: radius, tint: tint, front: true) }
        if detail >= .moon {
            let moon = CGRect(x: center.x + radius * 1.7 - radius * 0.2, y: center.y - radius * 1.1 - radius * 0.2, width: radius * 0.4, height: radius * 0.4)
            canvas.fill(Path(ellipseIn: moon), with: .color(Color.white.opacity(0.85)))
        }
        if look.flash > 0 {
            canvas.fill(Path(ellipseIn: sphere.insetBy(dx: -4, dy: -4)), with: .color(Color.white.opacity(0.5 * look.flash)))
        }
    }

    /// Faint belts across the planet, tilted with its ring, and two storms that cross its face as it turns, narrowing toward the limb.
    private static func drawSurface(in canvas: inout GraphicsContext, ball: Path, center: CGPoint, radius: CGFloat, look: Look) {
        canvas.drawLayer { surface in
            surface.clip(to: ball)
            surface.translateBy(x: center.x, y: center.y)
            surface.rotate(by: .degrees(-18))
            for (y, height, darker) in [(-0.55, 0.16, true), (-0.1, 0.12, false), (0.28, 0.2, true)] {
                let rect = CGRect(x: -radius, y: radius * y, width: radius * 2, height: radius * height)
                let tone = darker ? Color.black.opacity(0.14) : Color.white.opacity(0.12)
                surface.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [.clear, tone, .clear]), startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
                ))
            }
            let turn = (look.time ?? 0) / 48 * 2 * .pi
            for (latitude, longitude, size) in [(-0.32, 0.6, 0.26), (0.36, 3.4, 0.2)] {
                let facing = cos(longitude + turn)
                guard facing > 0.05 else { continue }
                let x = radius * sqrt(1 - latitude * latitude) * sin(longitude + turn)
                let width = radius * size * facing
                let height = radius * size * 0.5
                surface.fill(
                    Path(ellipseIn: CGRect(x: x - width, y: radius * latitude - height, width: width * 2, height: height * 2)),
                    with: .color(Color.white.opacity(0.13 * facing))
                )
            }
        }
    }

    /// The ring is tilted −18°; its far half goes behind the sphere and the near half in front.
    private static func drawRing(in canvas: inout GraphicsContext, center: CGPoint, radius: CGFloat, tint: Color, front: Bool) {
        var layer = canvas
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .degrees(-18))
        let rx = radius * 1.55
        let ry = radius * 0.45
        var arc = Path()
        arc.addArc(center: .zero, radius: 1, startAngle: .degrees(front ? 0 : 180), endAngle: .degrees(front ? 180 : 360), clockwise: false)
        let transform = CGAffineTransform(scaleX: rx, y: ry)
        layer.stroke(arc.applying(transform), with: .color(tint.opacity(front ? 0.9 : 0.5)), lineWidth: 1.2)
    }
}
