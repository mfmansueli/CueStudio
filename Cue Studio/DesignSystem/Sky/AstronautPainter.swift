//
//  AstronautPainter.swift
//  Cue Studio
//

import SwiftUI

/// The astronaut of the Adrift sky, drawn in a `Canvas` (no image): 37.5 pt from helmet to boots, in a white suit lit from the top left and shaded
/// toward the bottom right, with grey joints, gloves, boots and backpack, a loose tether, a chest panel with two small lights (one pulses every
/// 3 s) and a Cue-yellow patch on the shoulder. The helmet has a square mirrored visor: dark, with silver streaks, a bright star glint and a faint
/// reflection along its lower edge. Arms and legs drift a little out of step. Everything is a fraction of his size; the origin is the middle of the
/// body and `-y` is up.
enum AstronautPainter {
    static func draw(_ astronaut: StarfieldMath.Astronaut, time: TimeInterval, in canvas: inout GraphicsContext) {
        var layer = canvas
        layer.opacity = astronaut.opacity
        layer.translateBy(x: astronaut.position.x, y: astronaut.position.y)
        layer.rotate(by: .radians(astronaut.angle))
        let unit = astronaut.size
        // One light for the whole body: white where it comes from (top left), a cool grey on the far side.
        let suit = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Palette.astronautSuit, Palette.astronautSuitShade]),
            startPoint: CGPoint(x: -0.32 * unit, y: -0.45 * unit), endPoint: CGPoint(x: 0.32 * unit, y: 0.5 * unit)
        )

        drawTether(&layer, unit: unit, time: time)
        drawBackpack(&layer, unit: unit)
        drawLegs(&layer, unit: unit, time: time, suit: suit)
        drawArms(&layer, unit: unit, time: time, suit: suit)
        drawTorso(&layer, unit: unit, time: time, suit: suit)
        drawHelmet(&layer, unit: unit)
        drawVisor(&layer, unit: unit)
    }

    // MARK: - Behind the body

    /// A thin tether that floats loose from the backpack, swaying as if in no gravity.
    private static func drawTether(_ layer: inout GraphicsContext, unit: CGFloat, time: TimeInterval) {
        let sway = 0.05 * sin(time * 2 * .pi / 7)
        var cord = Path()
        cord.move(to: CGPoint(x: -0.22 * unit, y: 0.04 * unit))
        cord.addCurve(
            to: CGPoint(x: (-0.40 + sway) * unit, y: 0.30 * unit),
            control1: CGPoint(x: (-0.42 + sway) * unit, y: -0.02 * unit), control2: CGPoint(x: (-0.30 - sway) * unit, y: 0.22 * unit)
        )
        layer.stroke(cord, with: .color(Palette.astronautSilver.opacity(0.75)), style: StrokeStyle(lineWidth: max(0.5, unit * 0.014), lineCap: .round))
        let end = CGPoint(x: (-0.40 + sway) * unit, y: 0.30 * unit)
        layer.fill(
            Path(ellipseIn: CGRect(x: end.x - unit * 0.022, y: end.y - unit * 0.022, width: unit * 0.044, height: unit * 0.044)),
            with: .color(Palette.astronautSilver)
        )
    }

    private static func drawBackpack(_ layer: inout GraphicsContext, unit: CGFloat) {
        let pack = Path(roundedRect: CGRect(x: -0.235 * unit, y: -0.10 * unit, width: 0.47 * unit, height: 0.26 * unit), cornerRadius: 0.07 * unit)
        layer.fill(
            pack,
            with: .linearGradient(
                Gradient(colors: [Palette.astronautSuitShade, Palette.astronautSuitDeep]),
                startPoint: CGPoint(x: 0, y: -0.10 * unit), endPoint: CGPoint(x: 0, y: 0.16 * unit)
            )
        )
    }

    // MARK: - Limbs

    /// The legs, hanging a little apart and swaying out of step: a white leg with a grey knee and a grey boot.
    private static func drawLegs(_ layer: inout GraphicsContext, unit: CGFloat, time: TimeInterval, suit: GraphicsContext.Shading) {
        for side in [-1.0, 1.0] {
            let angle = side * 0.22 + 0.08 * sin(time * 2 * .pi / 6.5 + side * 1.1)
            let hip = CGPoint(x: side * 0.07 * unit, y: 0.16 * unit)
            let foot = point(from: hip, angle: angle, length: 0.27 * unit)
            tube(&layer, from: hip, to: foot, width: 0.13 * unit, shading: suit)
            band(&layer, from: hip, to: foot, at: 0.5, width: 0.145 * unit, thickness: 0.035 * unit)
            band(&layer, from: hip, to: foot, at: 0.93, width: 0.16 * unit, thickness: 0.085 * unit)
        }
    }

    /// The arms, raised and held out as if he were floating: a white sleeve, a grey elbow and a grey glove.
    private static func drawArms(_ layer: inout GraphicsContext, unit: CGFloat, time: TimeInterval, suit: GraphicsContext.Shading) {
        for side in [-1.0, 1.0] {
            let angle = side * 0.85 + 0.12 * sin(time * 2 * .pi / 5 + side * 1.3)
            let shoulder = CGPoint(x: side * 0.15 * unit, y: -0.07 * unit)
            let hand = point(from: shoulder, angle: angle, length: 0.28 * unit)
            tube(&layer, from: shoulder, to: hand, width: 0.105 * unit, shading: suit)
            band(&layer, from: shoulder, to: hand, at: 0.5, width: 0.12 * unit, thickness: 0.03 * unit)
            layer.fill(
                Path(ellipseIn: CGRect(x: hand.x - 0.062 * unit, y: hand.y - 0.062 * unit, width: 0.124 * unit, height: 0.124 * unit)),
                with: .color(Palette.astronautSuitDeep)
            )
        }
    }

    // MARK: - Body

    private static func drawTorso(_ layer: inout GraphicsContext, unit: CGFloat, time: TimeInterval, suit: GraphicsContext.Shading) {
        layer.fill(Path(roundedRect: CGRect(x: -0.17 * unit, y: -0.13 * unit, width: 0.34 * unit, height: 0.33 * unit), cornerRadius: 0.09 * unit), with: suit)
        // The belt.
        layer.fill(Path(CGRect(x: -0.165 * unit, y: 0.145 * unit, width: 0.33 * unit, height: 0.03 * unit)), with: .color(Palette.astronautSuitDeep))
        // The chest panel with its two lights: yellow, steady, and ion blue, pulsing once every 3 s.
        layer.fill(
            Path(roundedRect: CGRect(x: -0.10 * unit, y: -0.06 * unit, width: 0.20 * unit, height: 0.11 * unit), cornerRadius: 0.025 * unit),
            with: .color(Palette.astronautSuitDeep)
        )
        let pulse = pow(max(0, sin(time * 2 * .pi / 3)), 4)
        let strength = 0.45 + 0.55 * pulse
        let blue = CGPoint(x: 0.05 * unit, y: -0.005 * unit)
        layer.fill(
            Path(ellipseIn: CGRect(x: blue.x - 0.075 * unit, y: blue.y - 0.075 * unit, width: 0.15 * unit, height: 0.15 * unit)),
            with: .radialGradient(
                Gradient(colors: [Palette.shipEngine.opacity(0.55 * strength), Palette.shipEngine.opacity(0)]),
                center: blue, startRadius: 0, endRadius: 0.075 * unit
            )
        )
        layer.fill(
            Path(ellipseIn: CGRect(x: blue.x - 0.022 * unit, y: blue.y - 0.022 * unit, width: 0.044 * unit, height: 0.044 * unit)),
            with: .color(Palette.shipEngine.opacity(strength))
        )
        layer.fill(
            Path(ellipseIn: CGRect(x: -0.07 * unit, y: -0.027 * unit, width: 0.04 * unit, height: 0.04 * unit)),
            with: .color(Palette.acc)
        )
        // A Cue-yellow patch on the shoulder.
        layer.fill(
            Path(roundedRect: CGRect(x: -0.155 * unit, y: -0.115 * unit, width: 0.05 * unit, height: 0.05 * unit), cornerRadius: 0.01 * unit),
            with: .color(Palette.acc)
        )
    }

    private static func drawHelmet(_ layer: inout GraphicsContext, unit: CGFloat) {
        // The neck ring.
        layer.fill(
            Path(roundedRect: CGRect(x: -0.115 * unit, y: -0.14 * unit, width: 0.23 * unit, height: 0.045 * unit), cornerRadius: 0.02 * unit),
            with: .color(Palette.astronautSuitDeep)
        )
        let helmet = Path(ellipseIn: CGRect(x: -0.215 * unit, y: -0.525 * unit, width: 0.43 * unit, height: 0.43 * unit))
        layer.fill(
            helmet,
            with: .radialGradient(
                Gradient(colors: [Palette.astronautSuit, Palette.astronautSuit, Palette.astronautSuitShade]),
                center: CGPoint(x: -0.07 * unit, y: -0.40 * unit), startRadius: 0, endRadius: 0.34 * unit
            )
        )
    }

    // MARK: - The visor

    /// The square visor: dark glass going from deep indigo to black, crossed by two silver streaks, a bright star glint at the top left, a faint
    /// reflection of the cold light along its lower edge and a thin silver rim.
    private static func drawVisor(_ layer: inout GraphicsContext, unit: CGFloat) {
        let rect = CGRect(x: -0.135 * unit, y: -0.425 * unit, width: 0.27 * unit, height: 0.235 * unit)
        let glass = Path(roundedRect: rect, cornerRadius: 0.06 * unit)
        layer.fill(
            glass,
            with: .linearGradient(
                Gradient(colors: [Palette.astronautVisorTop, Palette.astronautVisorBottom]),
                startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )

        var inside = layer
        inside.clip(to: glass)
        // The cold light along the lower edge.
        inside.fill(
            Path(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)),
            with: .linearGradient(
                Gradient(colors: [Palette.astronautGlint.opacity(0), Palette.astronautGlint.opacity(0.28)]),
                startPoint: CGPoint(x: 0, y: rect.midY), endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )
        // Two slanted silver streaks, the first strong, the second faint.
        streak(&inside, unit: unit, top: (-0.115, -0.045), bottom: (-0.005, 0.065), strength: 0.8, rect: rect)
        streak(&inside, unit: unit, top: (0.005, 0.045), bottom: (0.115, 0.135), strength: 0.35, rect: rect)
        // The star glint.
        let glint = CGPoint(x: -0.085 * unit, y: -0.385 * unit)
        for angle in [0.0, 90.0] {
            let radians = angle * .pi / 180
            var arm = Path()
            arm.move(to: CGPoint(x: glint.x - cos(radians) * 0.04 * unit, y: glint.y - sin(radians) * 0.04 * unit))
            arm.addLine(to: CGPoint(x: glint.x + cos(radians) * 0.04 * unit, y: glint.y + sin(radians) * 0.04 * unit))
            inside.stroke(arm, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: max(0.5, unit * 0.012), lineCap: .round))
        }
        layer.stroke(glass, with: .color(Palette.astronautSilver), lineWidth: max(0.5, unit * 0.014))
    }

    /// One slanted band of silver across the visor, from `top` (x range at the top edge) to `bottom` (x range at the bottom edge), fading as it goes.
    private static func streak(
        _ layer: inout GraphicsContext, unit: CGFloat, top: (Double, Double), bottom: (Double, Double), strength: Double, rect: CGRect
    ) {
        var band = Path()
        band.move(to: CGPoint(x: top.0 * unit, y: rect.minY))
        band.addLine(to: CGPoint(x: top.1 * unit, y: rect.minY))
        band.addLine(to: CGPoint(x: bottom.1 * unit, y: rect.maxY))
        band.addLine(to: CGPoint(x: bottom.0 * unit, y: rect.maxY))
        band.closeSubpath()
        layer.fill(
            band,
            with: .linearGradient(
                Gradient(colors: [Palette.astronautSilver.opacity(strength), Palette.astronautSilver.opacity(0.05)]),
                startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )
    }

    // MARK: - Geometry

    /// A rounded limb in the body's white.
    private static func tube(_ layer: inout GraphicsContext, from start: CGPoint, to end: CGPoint, width: CGFloat, shading: GraphicsContext.Shading) {
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        layer.stroke(line, with: shading, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// A grey band across a limb (a joint, a boot), `thickness` long, centred `fraction` of the way from `start` to `end`.
    private static func band(
        _ layer: inout GraphicsContext, from start: CGPoint, to end: CGPoint, at fraction: CGFloat, width: CGFloat, thickness: CGFloat
    ) {
        let centre = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
        let length = hypot(end.x - start.x, end.y - start.y)
        let along = CGVector(dx: (end.x - start.x) / length, dy: (end.y - start.y) / length)
        var line = Path()
        line.move(to: CGPoint(x: centre.x - along.dx * thickness / 2, y: centre.y - along.dy * thickness / 2))
        line.addLine(to: CGPoint(x: centre.x + along.dx * thickness / 2, y: centre.y + along.dy * thickness / 2))
        layer.stroke(line, with: .color(Palette.astronautSuitDeep), style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }

    /// The point `length` from `start` at `angle` from straight down (positive is toward +x).
    private static func point(from start: CGPoint, angle: Double, length: CGFloat) -> CGPoint {
        CGPoint(x: start.x + sin(angle) * length, y: start.y + cos(angle) * length)
    }
}
