//
//  SpaceshipPainter.swift
//  Cue Studio
//

import SwiftUI

/// The spaceship of the Galactic sky, drawn in a `Canvas` (no image): a small angular craft, 16 to 22 pt long, with a faceted hull (light above,
/// shaded below), swept indigo wings edged with a thin cyan light, a visor, two engine slits and a tiny light on each wing tip. Behind it, a
/// hairline trail that follows the path the ship really flew, tapering and fading from ion blue to violet. Quiet on purpose: it is never fully opaque.
/// Everything on the craft is a fraction of its length; `+x` is forward.
enum SpaceshipPainter {
    static func draw(_ ship: StarfieldMath.Spaceship, time: TimeInterval, in canvas: inout GraphicsContext) {
        var layer = canvas
        layer.opacity = ship.opacity * 0.9
        // The engines breathe, fast and barely.
        let flicker = 0.88 + 0.12 * sin(time * 19)
        drawTrail(&layer, ship: ship, flicker: flicker)

        var craft = layer
        let position = ship.position
        craft.translateBy(x: position.x, y: position.y)
        craft.rotate(by: .radians(ship.heading))
        let length = ship.length
        drawWings(&craft, length: length)
        drawHull(&craft, length: length, flicker: flicker)
        drawLights(&craft, length: length, time: time)
    }

    // MARK: - The trail

    /// A hairline behind the engines along the curve the ship flew (not a straight line from it): 1.1 pt at the engine, tapering to nothing, with a
    /// faint wider glow under it, going from ion blue to violet as it fades. Drawn in the sky's own coordinates.
    private static func drawTrail(_ layer: inout GraphicsContext, ship: StarfieldMath.Spaceship, flicker: Double) {
        let steps = 32
        let reach = StarfieldMath.spaceshipTrailSeconds / ship.duration
        let width = ship.length * 0.06
        let position = ship.position
        var from = CGPoint(x: position.x - cos(ship.heading) * ship.length * 0.5, y: position.y - sin(ship.heading) * ship.length * 0.5)
        for step in 1...steps {
            let fraction = Double(step) / Double(steps)
            let moment = ship.time - reach * fraction
            guard moment >= 0 else { break }
            let to = ship.position(atTime: moment)
            let fade = pow(1 - fraction, 1.5) * flicker
            let colour = Palette.shipEngine.mix(with: Palette.shipTrailFar, by: fraction)
            var segment = Path()
            segment.move(to: from)
            segment.addLine(to: to)
            layer.stroke(segment, with: .color(colour.opacity(0.12 * fade)), style: StrokeStyle(lineWidth: width * 3.4 * (1 - fraction * 0.7)))
            layer.stroke(segment, with: .color(colour.opacity(0.8 * fade)), style: StrokeStyle(lineWidth: width * (1 - fraction * 0.75)))
            from = to
        }
    }

    // MARK: - The craft

    /// Two swept delta wings with a notch in the trailing edge, in deep indigo, and a cyan light along each leading edge.
    private static func drawWings(_ craft: inout GraphicsContext, length: CGFloat) {
        for side in [-1.0, 1.0] {
            let wing = polygon([(0.14, side * 0.07), (-0.34, side * 0.38), (-0.42, side * 0.36), (-0.30, side * 0.17), (-0.46, side * 0.06)], length)
            craft.fill(wing, with: .color(Palette.shipWing))
            var edge = Path()
            edge.move(to: point(0.14, side * 0.07, length))
            edge.addLine(to: point(-0.34, side * 0.38, length))
            craft.stroke(edge, with: .color(Palette.shipEngine.opacity(0.85)), lineWidth: max(0.4, length * 0.028))
        }
    }

    /// The faceted hull, the engine slits with their glow, and the visor.
    private static func drawHull(_ craft: inout GraphicsContext, length: CGFloat, flicker: Double) {
        let engine = Palette.shipEngine
        let glow = point(-0.5, 0, length)
        craft.fill(
            Path(ellipseIn: CGRect(x: glow.x - length * 0.35, y: glow.y - length * 0.35, width: length * 0.7, height: length * 0.7)),
            with: .radialGradient(Gradient(colors: [engine.opacity(0.5 * flicker), engine.opacity(0)]), center: glow, startRadius: 0, endRadius: length * 0.35)
        )

        craft.fill(polygon([(0.5, 0), (0.10, -0.08), (-0.5, -0.06), (-0.40, 0)], length), with: .color(Palette.shipHull))
        craft.fill(polygon([(0.5, 0), (-0.40, 0), (-0.5, 0.06), (0.10, 0.08)], length), with: .color(Palette.shipHullShade))

        for side in [-1.0, 1.0] {
            craft.fill(polygon([(-0.46, side * 0.049), (-0.53, side * 0.049), (-0.53, side * 0.021), (-0.46, side * 0.021)], length), with: .color(engine))
        }

        craft.fill(polygon([(0.31, 0), (0.20, -0.028), (0.14, 0), (0.20, 0.028)], length), with: .color(engine.mix(with: .white, by: 0.6)))
    }

    /// A light on each wing tip, flashing once every 2.8 s in turn (the port one first) and barely glowing in between.
    private static func drawLights(_ craft: inout GraphicsContext, length: CGFloat, time: TimeInterval) {
        let phase = time.truncatingRemainder(dividingBy: 2.8) / 2.8
        let lights: [(side: Double, color: Color, lit: Bool)] = [
            (-1, Palette.shipLightPort, phase < 0.05),
            (1, Palette.shipLightStarboard, phase >= 0.5 && phase < 0.55),
        ]
        for light in lights {
            let centre = point(-0.38, light.side * 0.375, length)
            let strength = light.lit ? 1.0 : 0.3
            craft.fill(
                Path(ellipseIn: CGRect(x: centre.x - length * 0.11, y: centre.y - length * 0.11, width: length * 0.22, height: length * 0.22)),
                with: .radialGradient(
                    Gradient(colors: [light.color.opacity(0.6 * strength), light.color.opacity(0)]),
                    center: centre, startRadius: 0, endRadius: length * 0.11
                )
            )
            craft.fill(
                Path(ellipseIn: CGRect(x: centre.x - length * 0.035, y: centre.y - length * 0.035, width: length * 0.07, height: length * 0.07)),
                with: .color(light.color.opacity(strength))
            )
        }
    }

    // MARK: - Geometry

    private static func point(_ x: Double, _ y: Double, _ length: CGFloat) -> CGPoint {
        CGPoint(x: x * length, y: y * length)
    }

    private static func polygon(_ corners: [(Double, Double)], _ length: CGFloat) -> Path {
        var path = Path()
        for (index, corner) in corners.enumerated() {
            let spot = point(corner.0, corner.1, length)
            if index == 0 { path.move(to: spot) } else { path.addLine(to: spot) }
        }
        path.closeSubpath()
        return path
    }
}
