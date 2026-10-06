//
//  PlanetPainter.swift
//  Cue Studio
//

import SwiftUI

/// A platform's planet on the universe map (9.2): a sphere lit from the upper left in the platform's colour, with the details it earns, a glow at 52
/// videos, a thin ring at 156 and a small moon at 365 (`PlanetSize`). Drawn in board points.
enum PlanetPainter {
    /// How far its label sits from the planet's centre along x: 6 pt beyond the planet, or beyond the ring when there is one.
    static func labelDistance(diameter: CGFloat, detail: PlanetSize.Detail) -> CGFloat {
        let radius = diameter / 2
        return (detail >= .ring ? radius * 1.55 : radius) + 6
    }

    static func draw(
        in canvas: inout GraphicsContext, center: CGPoint, diameter: CGFloat, detail: PlanetSize.Detail, tint: Color, opacity: Double = 1, flash: Double = 0
    ) {
        guard diameter > 0 else { return }
        let faded = canvas.opacity
        canvas.opacity = faded * opacity
        defer { canvas.opacity = faded }
        let radius = diameter / 2
        let halo = detail >= .glow ? radius * 2.6 : radius * 1.8
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(detail >= .glow ? 0.5 : 0.28), tint.opacity(0)]),
                center: center, startRadius: radius * 0.6, endRadius: halo
            )
        )
        if detail >= .ring { drawRing(in: &canvas, center: center, radius: radius, tint: tint, front: false) }
        let sphere = CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter)
        canvas.fill(
            Path(ellipseIn: sphere),
            with: .radialGradient(
                Gradient(colors: [tint.mix(with: .white, by: 0.55), tint, tint.mix(with: .black, by: 0.45)]),
                center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.4), startRadius: 0, endRadius: radius * 1.4
            )
        )
        if detail >= .ring { drawRing(in: &canvas, center: center, radius: radius, tint: tint, front: true) }
        if detail >= .moon {
            let moon = CGRect(x: center.x + radius * 1.7 - radius * 0.2, y: center.y - radius * 1.1 - radius * 0.2, width: radius * 0.4, height: radius * 0.4)
            canvas.fill(Path(ellipseIn: moon), with: .color(Color.white.opacity(0.85)))
        }
        if flash > 0 {
            canvas.fill(Path(ellipseIn: sphere.insetBy(dx: -4, dy: -4)), with: .color(Color.white.opacity(0.5 * flash)))
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
