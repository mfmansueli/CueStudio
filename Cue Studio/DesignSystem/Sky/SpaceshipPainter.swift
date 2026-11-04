//
//  SpaceshipPainter.swift
//  Cue Studio
//

import SwiftUI

/// The spaceship of the Interstellar sky, drawn in a `Canvas` (no image): a small angular craft, 16 to 22 pt long, with a faceted hull (light above,
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

        drawCraft(at: ship.position, heading: ship.heading, length: ship.length, time: time, in: &layer)
    }

    /// The craft alone (no trail), nose at `heading`, centred on `position`: the sky's ship, and the one that fills My Cue Voice's tank
    /// (`VoiceFuelPainter`). `bank` (−1…1) darkens the lower wing as the ship rolls into a turn (positive: the port one); `thrust` grows the
    /// engines' glow as they charge and burn.
    static func drawCraft(
        at position: CGPoint, heading: Double, length: CGFloat, time: TimeInterval, bank: Double = 0, thrust: Double = 1,
        in canvas: inout GraphicsContext
    ) {
        var craft = canvas
        craft.translateBy(x: position.x, y: position.y)
        craft.rotate(by: .radians(heading))
        drawWings(&craft, length: length, bank: bank)
        drawHull(&craft, length: length, flicker: 0.88 + 0.12 * sin(time * 19), thrust: thrust)
        drawLights(&craft, length: length, time: time)
    }

    /// The same craft seen from the front, nose at the viewer (`size` is its span's worth): the engines' light around it from behind, the swept
    /// wings spreading to each side and a little down, thick at the root and lit along their cyan leading edges with a light at each tip, a
    /// small fin on top, and the round hull lit from above with its visor. `opening` (0…1) is how far it has turned to face the screen: at 0 it
    /// is a sliver, as the top view becomes this one.
    static func drawCraftFront(
        at position: CGPoint, size: CGFloat, opening: Double, thrust: Double, time: TimeInterval, in canvas: inout GraphicsContext
    ) {
        var craft = canvas
        craft.translateBy(x: position.x, y: position.y)
        craft.scaleBy(x: 1, y: CGFloat(max(0.04, opening)))
        let engine = Palette.Sky.shipEngine
        let flicker = 0.88 + 0.12 * sin(time * 19)
        // The engines are behind the hull: their light only rims it, close and soft.
        let halo = size * 0.34 * CGFloat(min(1.6, thrust))
        craft.fill(
            Path(ellipseIn: CGRect(x: -halo, y: -halo * 0.8, width: halo * 2, height: halo * 1.6)),
            with: .radialGradient(
                Gradient(colors: [engine.opacity(0.45 * flicker), engine.opacity(0.12 * flicker), engine.opacity(0)]),
                center: .zero, startRadius: size * 0.08, endRadius: halo
            )
        )
        for side in [-1.0, 1.0] {
            let wing = polygon([(side * 0.12, -0.06), (side * 0.50, 0.06), (side * 0.50, 0.12), (side * 0.13, 0.15)], size)
            craft.fill(wing, with: .linearGradient(
                Gradient(colors: [Palette.Sky.shipWing.mix(with: .white, by: 0.18), Palette.Sky.shipWing.mix(with: .black, by: 0.35)]),
                startPoint: point(0, -0.06, size), endPoint: point(0, 0.15, size)
            ))
            var edge = Path()
            edge.move(to: point(side * 0.12, -0.06, size))
            edge.addLine(to: point(side * 0.50, 0.06, size))
            craft.stroke(edge, with: .color(engine.opacity(0.95)), style: StrokeStyle(lineWidth: max(0.6, size * 0.022), lineCap: .round))
            let tip = point(side * 0.50, 0.09, size)
            let lit = side < 0 ? Palette.Sky.shipLightPort : Palette.Sky.shipLightStarboard
            let pulse = 0.6 + 0.4 * sin(time * 9 + side)
            let glow = size * 0.05
            craft.fill(
                Path(ellipseIn: CGRect(x: tip.x - glow, y: tip.y - glow, width: glow * 2, height: glow * 2)),
                with: .radialGradient(Gradient(colors: [lit.opacity(0.8 * pulse), lit.opacity(0)]), center: tip, startRadius: 0, endRadius: glow)
            )
            craft.fill(
                Path(ellipseIn: CGRect(x: tip.x - glow * 0.3, y: tip.y - glow * 0.3, width: glow * 0.6, height: glow * 0.6)),
                with: .color(lit.opacity(pulse))
            )
        }
        craft.fill(polygon([(-0.025, -0.13), (0, -0.24), (0.025, -0.13)], size), with: .color(Palette.Sky.shipHullShade))
        let hull = CGRect(x: -size * 0.15, y: -size * 0.14, width: size * 0.30, height: size * 0.28)
        craft.fill(Path(ellipseIn: hull), with: .linearGradient(
            Gradient(colors: [Palette.Sky.shipHull, Palette.Sky.shipHullShade, Palette.Sky.shipWing.mix(with: Palette.Sky.shipHullShade, by: 0.5)]),
            startPoint: CGPoint(x: 0, y: hull.minY), endPoint: CGPoint(x: 0, y: hull.maxY)
        ))
        let visor = CGRect(x: -size * 0.09, y: -size * 0.085, width: size * 0.18, height: size * 0.085)
        craft.fill(Path(ellipseIn: visor), with: .linearGradient(
            Gradient(colors: [engine.mix(with: .white, by: 0.65), engine.mix(with: Palette.Sky.shipWing, by: 0.55)]),
            startPoint: CGPoint(x: 0, y: visor.minY), endPoint: CGPoint(x: 0, y: visor.maxY)
        ))
        let glint = CGRect(x: -size * 0.06, y: -size * 0.078, width: size * 0.05, height: size * 0.022)
        craft.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.9)))
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
            let colour = Palette.Sky.shipEngine.mix(with: Palette.Sky.shipTrailFar, by: fraction)
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
    private static func drawWings(_ craft: inout GraphicsContext, length: CGFloat, bank: Double = 0) {
        for side in [-1.0, 1.0] {
            let wing = polygon([(0.14, side * 0.07), (-0.34, side * 0.38), (-0.42, side * 0.36), (-0.30, side * 0.17), (-0.46, side * 0.06)], length)
            // The wing that dips in a bank is turned away from the light; the other catches it.
            let lowered = max(0, -side * bank)
            let raised = max(0, side * bank)
            let wingColour = Palette.Sky.shipWing.mix(with: .black, by: 0.45 * lowered).mix(with: .white, by: 0.15 * raised)
            craft.fill(wing, with: .color(wingColour))
            var edge = Path()
            edge.move(to: point(0.14, side * 0.07, length))
            edge.addLine(to: point(-0.34, side * 0.38, length))
            craft.stroke(edge, with: .color(Palette.Sky.shipEngine.opacity(0.85)), lineWidth: max(0.4, length * 0.028))
        }
    }

    /// The faceted hull, the engine slits with their glow, and the visor.
    private static func drawHull(_ craft: inout GraphicsContext, length: CGFloat, flicker: Double, thrust: Double = 1) {
        let engine = Palette.Sky.shipEngine
        let glow = point(-0.5, 0, length)
        let reach = length * 0.35 * CGFloat(thrust)
        craft.fill(
            Path(ellipseIn: CGRect(x: glow.x - reach, y: glow.y - reach, width: reach * 2, height: reach * 2)),
            with: .radialGradient(
                Gradient(colors: [engine.opacity(min(0.85, 0.5 * thrust) * flicker), engine.opacity(0)]), center: glow, startRadius: 0, endRadius: reach
            )
        )

        craft.fill(polygon([(0.5, 0), (0.10, -0.08), (-0.5, -0.06), (-0.40, 0)], length), with: .color(Palette.Sky.shipHull))
        craft.fill(polygon([(0.5, 0), (-0.40, 0), (-0.5, 0.06), (0.10, 0.08)], length), with: .color(Palette.Sky.shipHullShade))

        for side in [-1.0, 1.0] {
            craft.fill(polygon([(-0.46, side * 0.049), (-0.53, side * 0.049), (-0.53, side * 0.021), (-0.46, side * 0.021)], length), with: .color(engine))
        }

        craft.fill(polygon([(0.31, 0), (0.20, -0.028), (0.14, 0), (0.20, 0.028)], length), with: .color(engine.mix(with: .white, by: 0.6)))
    }

    /// A light on each wing tip, flashing once every 2.8 s in turn (the port one first) and barely glowing in between.
    private static func drawLights(_ craft: inout GraphicsContext, length: CGFloat, time: TimeInterval) {
        let phase = time.truncatingRemainder(dividingBy: 2.8) / 2.8
        let lights: [(side: Double, color: Color, lit: Bool)] = [
            (-1, Palette.Sky.shipLightPort, phase < 0.05),
            (1, Palette.Sky.shipLightStarboard, phase >= 0.5 && phase < 0.55),
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
