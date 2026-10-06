//
//  GalaxyPainter.swift
//  Cue Studio
//

import SwiftUI

/// Draws the galaxies of `GalaxyArt` into a `Canvas`: a platform's galaxy (glow, two arms of gas and light turning slowly, a few stars, a core)
/// and the creator's (the same with a thousand stars, a bulge, three orbits with a planet each, a turning cross of light and a lit core).
/// All lengths are the board's points: the platform galaxies are drawn where they sit on the 390 × 844 board, the hero at its own 360 pt.
enum GalaxyPainter {
    // MARK: - A platform's galaxy

    /// The galaxy of `art` at its place on the board, turned `spin` degrees (the arms only) and scaled by `scale` about its centre.
    static func drawSocial(_ art: GalaxyArt.Social, in context: inout GraphicsContext, spin: Double, scale: CGFloat = 1) {
        let color = Color(.sRGB, red: Double(art.rgb[0]) / 255, green: Double(art.rgb[1]) / 255, blue: Double(art.rgb[2]) / 255)
        var layer = context
        layer.translateBy(x: art.center[0], y: art.center[1])
        layer.rotate(by: .degrees(art.rotation))
        layer.scaleBy(x: scale, y: scale * art.squash)
        // The soft disc under it.
        layer.fill(
            circle(art.glowRadius),
            with: .radialGradient(Gradient(colors: [color.opacity(0.35), color.opacity(0)]), center: .zero, startRadius: 0, endRadius: art.glowRadius)
        )
        // The arms, turning, shaded from white at the core to the colour and out to nothing at their tips.
        var arms = layer
        arms.rotate(by: .degrees(spin))
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.95), location: 0), .init(color: color.opacity(0.9), location: 0.3), .init(color: color.opacity(0), location: 1),
            ]),
            center: .zero, startRadius: 0, endRadius: art.armRadius
        )
        for arm in art.arms {
            let path = polyline(arm.points)
            if arm.blurred {
                arms.drawLayer { blurred in
                    blurred.addFilter(.blur(radius: 2.4))
                    blurred.opacity = arm.opacity
                    blurred.stroke(path, with: shading, lineWidth: arm.width)
                }
            } else {
                arms.stroke(path, with: shading, style: StrokeStyle(lineWidth: arm.width, lineCap: .round, lineJoin: .round))
            }
        }
        for star in art.stars {
            arms.fill(
                Path(ellipseIn: CGRect(x: star.x - star.radius, y: star.y - star.radius, width: star.radius * 2, height: star.radius * 2)),
                with: .color(Color(hex: hex(star.color)).opacity(star.opacity))
            )
        }
        // The core.
        layer.fill(
            circle(art.coreRadius),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white, location: 0), .init(color: .white.opacity(0.9), location: 0.35),
                    .init(color: color.opacity(0.55), location: 0.7), .init(color: color.opacity(0), location: 1),
                ]),
                center: .zero, startRadius: 0, endRadius: art.coreRadius
            )
        )
    }

    // MARK: - The creator's galaxy

    /// The disc of the creator's galaxy (the gas, the light and the stars) without the sky around it: the part that only turns, drawn once into
    /// an image (360 × 360 pt) and turned afterwards. The context's origin is the middle of the image.
    static func drawHeroDisc(_ hero: GalaxyArt.Hero, in context: inout GraphicsContext) {
        for arm in hero.arms {
            let path = polyline(arm.points)
            let color = Color(hex: hex(arm.stroke ?? "#FFFFFF")).opacity(arm.opacity)
            if arm.blurred {
                context.drawLayer { blurred in
                    blurred.addFilter(.blur(radius: arm.width > 10 ? 9 : 2.2))
                    blurred.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: arm.width, lineCap: .round, lineJoin: .round))
                }
            } else {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: arm.width, lineCap: .round, lineJoin: .round))
            }
        }
        for star in hero.stars {
            context.fill(
                Path(ellipseIn: CGRect(x: star.x - star.radius, y: star.y - star.radius, width: star.radius * 2, height: star.radius * 2)),
                with: .color(Color(hex: hex(star.color)).opacity(star.opacity))
            )
        }
    }

    /// The creator's galaxy, 360 pt across, centred on the context's origin, `time` seconds into its life (its turns and its orbits' laps).
    /// `disc` is the pre-rendered disc (`drawHeroDisc`); without it the disc is drawn live.
    static func drawHero(
        _ hero: GalaxyArt.Hero, in context: inout GraphicsContext, time: Double, disc: GraphicsContext.ResolvedImage?
    ) {
        var tilted = context
        tilted.rotate(by: .degrees(-18))
        // The galaxy: a soft gold-and-violet light, the disc turning once in 140 s, and the bulge, all squashed to 0.52 high.
        var flat = tilted
        flat.scaleBy(x: 1, y: 0.52)
        flat.fill(circle(175), with: .radialGradient(Gradient(stops: heroGlow), center: .zero, startRadius: 0, endRadius: 175))
        var turning = flat
        turning.rotate(by: .degrees(time / 140 * 360))
        if let disc {
            turning.draw(disc, in: CGRect(x: -180, y: -180, width: 360, height: 360))
        } else {
            drawHeroDisc(hero, in: &turning)
        }
        flat.fill(circle(60), with: .radialGradient(Gradient(stops: heroBulge), center: .zero, startRadius: 0, endRadius: 60))
        drawOrbits(in: tilted, time: time)
        context.fill(circle(64), with: .radialGradient(Gradient(stops: heroHalo), center: .zero, startRadius: 0, endRadius: 64))
        drawFlare(in: context, time: time)
        drawCore(in: context)
    }

    /// An orbit of the creator's galaxy: its ellipse, the planet on it (radius, lap time, where in its lap it started) and the planet's shading.
    private struct Orbit {
        let rx: Double
        let ry: Double
        let radius: Double
        let period: Double
        let begin: Double
        let stops: [Gradient.Stop]
    }

    private static func drawOrbits(in context: GraphicsContext, time: Double) {
        let orbits = [
            Orbit(rx: 52, ry: 27, radius: 10, period: 9, begin: 0, stops: planet(0xFFD3EC, 0xFF6FB5, 0x8F2A63)),
            Orbit(rx: 92, ry: 48, radius: 12, period: 16, begin: -5, stops: planet(0xBFF5DC, 0x34C98E, 0x14634A)),
            Orbit(rx: 132, ry: 69, radius: 15, period: 24, begin: -9, stops: planet(0xFFD39A, 0xFF9F0A, 0x8A4B00)),
        ]
        let layer = context
        for orbit in orbits {
            layer.stroke(
                Path(ellipseIn: CGRect(x: -orbit.rx, y: -orbit.ry, width: orbit.rx * 2, height: orbit.ry * 2)),
                with: .color(Palette.starLilac.opacity(0.26)), lineWidth: 1.1
            )
            // The planet laps its ellipse clockwise from its right-hand end, `period` seconds a lap.
            let angle = (time - orbit.begin) / orbit.period * 2 * .pi
            let centre = CGPoint(x: orbit.rx * cos(angle), y: orbit.ry * sin(angle))
            layer.fill(
                Path(ellipseIn: CGRect(x: centre.x - orbit.radius, y: centre.y - orbit.radius, width: orbit.radius * 2, height: orbit.radius * 2)),
                with: .radialGradient(
                    Gradient(stops: orbit.stops), center: CGPoint(x: centre.x - orbit.radius * 0.32, y: centre.y - orbit.radius * 0.4),
                    startRadius: 0, endRadius: orbit.radius * 1.56
                )
            )
        }
    }

    /// The cross of light over the core, turning once in 40 s.
    private static func drawFlare(in context: GraphicsContext, time: Double) {
        var layer = context
        layer.rotate(by: .degrees(time / 40 * 360))
        var cross = Path()
        cross.move(to: CGPoint(x: -46, y: 0))
        cross.addLine(to: CGPoint(x: 46, y: 0))
        cross.move(to: CGPoint(x: 0, y: -46))
        cross.addLine(to: CGPoint(x: 0, y: 46))
        layer.stroke(cross, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        var diagonals = Path()
        diagonals.move(to: CGPoint(x: -30, y: -30))
        diagonals.addLine(to: CGPoint(x: 30, y: 30))
        diagonals.move(to: CGPoint(x: 30, y: -30))
        diagonals.addLine(to: CGPoint(x: -30, y: 30))
        layer.stroke(diagonals, with: .color(Palette.starLilac.opacity(0.3)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    /// The core: a lit sphere (`#fff → #F4F0FF → #D2C8FF → #9D8CFF → #6E5BE6`, light from the top left), a thin rim and a bright oval of reflection.
    private static func drawCore(in context: GraphicsContext) {
        var layer = context
        layer.fill(
            circle(20),
            with: .radialGradient(Gradient(stops: heroCore), center: CGPoint(x: -20 * 0.32, y: -20 * 0.44), startRadius: 0, endRadius: 32)
        )
        layer.stroke(circle(20), with: .color(.white.opacity(0.5)), lineWidth: 0.8)
        layer.translateBy(x: -6.5, y: -8)
        layer.rotate(by: .degrees(-30))
        layer.fill(Path(ellipseIn: CGRect(x: -6, y: -3.6, width: 12, height: 7.2)), with: .color(.white.opacity(0.85)))
    }

    // MARK: - Pieces

    private static let heroGlow: [Gradient.Stop] = [
        .init(color: Color(hex: 0xFFE080).opacity(0.55), location: 0), .init(color: Color(hex: 0xE9B94A).opacity(0.28), location: 0.25),
        .init(color: Palette.nightViolet.opacity(0.14), location: 0.6), .init(color: Palette.nightViolet.opacity(0), location: 1),
    ]
    private static let heroBulge: [Gradient.Stop] = [
        .init(color: .white, location: 0), .init(color: Color(hex: 0xFFF3C4).opacity(0.95), location: 0.18),
        .init(color: Palette.acc.opacity(0.5), location: 0.45), .init(color: Palette.acc.opacity(0), location: 1),
    ]
    private static let heroHalo: [Gradient.Stop] = [
        .init(color: Color(hex: 0xC9BFFF).opacity(0.7), location: 0), .init(color: Palette.nightViolet.opacity(0.25), location: 0.5),
        .init(color: Palette.nightViolet.opacity(0), location: 1),
    ]
    private static let heroCore: [Gradient.Stop] = [
        .init(color: .white, location: 0), .init(color: Color(hex: 0xF4F0FF), location: 0.22), .init(color: Color(hex: 0xD2C8FF), location: 0.52),
        .init(color: Palette.nightViolet, location: 0.82), .init(color: Color(hex: 0x6E5BE6), location: 1),
    ]

    private static func planet(_ light: UInt32, _ body: UInt32, _ shade: UInt32) -> [Gradient.Stop] {
        [
            .init(color: .white, location: 0), .init(color: Color(hex: light), location: 0.25), .init(color: Color(hex: body), location: 0.7),
            .init(color: Color(hex: shade), location: 1),
        ]
    }

    private static func circle(_ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    }

    private static func polyline(_ points: [[Double]]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let at = CGPoint(x: point[0], y: point[1])
            if index == 0 { path.move(to: at) } else { path.addLine(to: at) }
        }
        return path
    }

    /// `#FFE08A` or `#fff` as the number `Color(hex:)` takes.
    private static func hex(_ text: String) -> UInt32 {
        var digits = String(text.dropFirst())
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        return UInt32(digits, radix: 16) ?? 0xFFFFFF
    }
}
