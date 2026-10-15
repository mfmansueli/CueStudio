//
//  ProPlanetArt.swift
//  Cue Studio
//

import SwiftUI

/// "You are the main planet" (09, Pro art, with the owner's finish on top): a 68 pt golden planet in a soft gold atmosphere that breathes, with
/// faint bands, a shaded night side, a rim of light and now and then a glint; two orbits tilted −7° that pass behind it and in front of it
/// (236 × 40 warm and 350 × 58 lavender), fine dust drifting on them; three small platform planets travelling them with a short trail (TikTok
/// and Reels on the outer one, 26 s; Shorts on the inner one, 17 s) and a faint band of light drifting across the planet (9 s). On the opening
/// (`time`, `ProOpeningScript`) the planet is born white-hot and cools to gold, the orbits draw round it and the small planets come in. No
/// photo, no face. Still under Reduce Motion.
struct ProPlanetArt: View {
    /// The second of the opening; its end shows everything in place.
    var time = ProOpeningScript.settled

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Orbit {
        let width: CGFloat
        let height: CGFloat
        let color: Color
        let dust: Int
    }

    private struct Traveller {
        let orbit: Int
        let size: CGFloat
        let color: Color
        let period: Double
        let start: Double
    }

    static let planetRadius: CGFloat = 34
    /// The art's height, and where the planet's centre is in it.
    static let height: CGFloat = 220
    static let centreY: CGFloat = 110
    private static let tilt = Angle.degrees(-7)

    private static let orbits = [
        Orbit(width: 236, height: 40, color: Palette.World.warm.opacity(0.5), dust: 18),
        Orbit(width: 350, height: 58, color: Palette.aiTextStrong.opacity(0.4), dust: 30),
    ]

    private static let travellers = [
        Traveller(orbit: 1, size: 11, color: Palette.Platform.tikTok, period: 26, start: 0.2),
        Traveller(orbit: 1, size: 8, color: Palette.Platform.reels, period: 26, start: 3.4),
        Traveller(orbit: 0, size: 7, color: Palette.Platform.shorts, period: 17, start: 1.1),
    ]

    var body: some View {
        AmbientTimeline { ambient in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, ambient: reduceMotion ? 0 : ambient.seconds)
            }
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, ambient: TimeInterval) {
        let birth = ProOpeningScript.planet.pose(at: time)
        let drawn = ProOpeningScript.orbitsDraw.pose(at: time).scale
        let arrived = ProOpeningScript.travellers.pose(at: time).opacity
        var layer = canvas
        layer.translateBy(x: size.width / 2, y: Self.centreY)
        atmosphere(in: &layer, birth: birth, ambient: ambient)
        // What is behind the planet: the far half of each orbit, its dust and the small planets on it.
        layer.drawLayer { behind in
            behind.rotate(by: Self.tilt)
            for orbit in Self.orbits {
                stroke(orbit, half: .back, drawn: drawn, in: &behind)
                dust(on: orbit, half: .back, opacity: drawn, ambient: ambient, in: &behind)
            }
            for traveller in Self.travellers where isBehind(traveller, at: ambient) { draw(traveller, at: ambient, opacity: arrived, in: &behind) }
        }
        planet(in: &layer, birth: birth, ambient: ambient)
        layer.drawLayer { front in
            front.rotate(by: Self.tilt)
            for orbit in Self.orbits {
                stroke(orbit, half: .front, drawn: drawn, in: &front)
                dust(on: orbit, half: .front, opacity: drawn, ambient: ambient, in: &front)
            }
            for traveller in Self.travellers where !isBehind(traveller, at: ambient) { draw(traveller, at: ambient, opacity: arrived, in: &front) }
        }
    }

    // MARK: - The planet

    /// The soft gold air round it, breathing slowly (6 s).
    private func atmosphere(in canvas: inout GraphicsContext, birth: Pose, ambient: TimeInterval) {
        let breath = (1 - cos(ambient / 6 * 2 * .pi)) / 2
        let reach = 110 * birth.scale * (0.94 + 0.08 * breath)
        canvas.fill(
            disc(.zero, reach),
            with: .radialGradient(
                Gradient(colors: [Palette.World.warm.opacity((0.32 + 0.06 * breath) * birth.opacity), .clear]), center: .zero, startRadius: 0,
                endRadius: reach
            )
        )
    }

    private func planet(in canvas: inout GraphicsContext, birth: Pose, ambient: TimeInterval) {
        guard birth.opacity > 0.01 else { return }
        let radius = Self.planetRadius * birth.scale
        let ball = disc(.zero, radius)
        var layer = canvas
        layer.opacity = birth.opacity
        layer.drawLayer { lit in
            lit.addFilter(.shadow(color: Palette.World.warm.opacity(0.45), radius: 16))
            lit.fill(ball, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Palette.Universe.proPlanetLight, location: 0), .init(color: Palette.Universe.proPlanetMid, location: 0.32),
                    .init(color: Palette.Universe.proPlanetShade, location: 0.66), .init(color: Palette.Universe.proPlanetDark, location: 1),
                ]),
                center: CGPoint(x: -radius * 0.4, y: -radius * 0.4), startRadius: 0, endRadius: radius * 1.7
            ))
        }
        layer.drawLayer { surface in
            surface.clip(to: ball)
            // Faint bands across it, along the orbits' tilt.
            surface.rotate(by: Self.tilt)
            for band in [(y: -0.42, height: 0.12), (y: 0.05, height: 0.09), (y: 0.38, height: 0.14)] {
                surface.fill(
                    Path(CGRect(x: -radius, y: radius * band.y, width: radius * 2, height: radius * band.height)),
                    with: .color(Palette.Universe.proPlanetShade.opacity(0.18))
                )
            }
            surface.rotate(by: -Self.tilt)
            // The night side, away from the light.
            surface.fill(ball, with: .radialGradient(
                Gradient(colors: [.clear, .clear, .black.opacity(0.38)]), center: CGPoint(x: -radius * 0.45, y: -radius * 0.45), startRadius: 0,
                endRadius: radius * 2
            ))
            // A band of light crossing it every 9 s.
            let cycle = ambient.truncatingRemainder(dividingBy: 9) / 9
            surface.rotate(by: .degrees(20))
            let x = -radius * 2 + cycle * radius * 4
            surface.fill(
                Path(CGRect(x: x - 8, y: -radius * 1.5, width: 16, height: radius * 3)),
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0), .white.opacity(0.18), .white.opacity(0)]),
                    startPoint: CGPoint(x: x - 8, y: 0), endPoint: CGPoint(x: x + 8, y: 0)
                )
            )
        }
        // The rim of light on the lit side.
        var rim = Path()
        rim.addArc(center: .zero, radius: radius - 0.6, startAngle: .degrees(150), endAngle: .degrees(300), clockwise: false)
        layer.drawLayer { edge in
            edge.addFilter(.blur(radius: 0.8))
            edge.stroke(rim, with: .color(Palette.Universe.starCream.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        // Born white-hot, it cools to its gold.
        let white = ProOpeningScript.whiteHot.pose(at: time).opacity
        if white > 0.01 {
            layer.drawLayer { hot in
                hot.addFilter(.shadow(color: .white.opacity(white), radius: 18))
                hot.fill(ball, with: .color(.white.opacity(white)))
            }
        }
        glint(in: &layer, radius: radius, ambient: ambient)
    }

    /// Every 7 s, a short cross of light on the planet's lit shoulder.
    private func glint(in canvas: inout GraphicsContext, radius: CGFloat, ambient: TimeInterval) {
        let into = ambient.truncatingRemainder(dividingBy: 7)
        guard ambient > 3, into < 0.5 else { return }
        let strength = sin(.pi * into / 0.5)
        LightFX.cross(
            at: CGPoint(x: -radius * 0.55, y: -radius * 0.62), size: 26 * strength, thickness: 1.2, verticalRatio: 1,
            pose: MotionPose(opacity: strength, rot: 15), color: .white, glow: Palette.Universe.starCream, in: &canvas
        )
    }

    // MARK: - Orbits

    private enum Half { case back, front }

    /// Half an orbit, as much of it as has been drawn: the drawing starts at the left end, goes round behind and comes back in front. The far
    /// half is fainter.
    private func stroke(_ orbit: Orbit, half: Half, drawn: Double, in canvas: inout GraphicsContext) {
        let end = Double.pi + 2 * .pi * drawn
        let range: ClosedRange<Double>
        switch half {
        case .back: range = Double.pi...min(2 * .pi, end)
        case .front:
            guard end > 2 * .pi else { return }
            range = 0...(end - 2 * .pi)
        }
        guard range.upperBound > range.lowerBound else { return }
        var path = Path()
        for step in 0...48 {
            let theta = range.lowerBound + (range.upperBound - range.lowerBound) * Double(step) / 48
            let point = point(on: orbit, at: theta)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        canvas.stroke(path, with: .color(orbit.color.opacity(half == .back ? 0.6 : 1)), lineWidth: half == .back ? 0.8 : 1.1)
    }

    /// Fine dust drifting along an orbit, each speck twinkling on its own.
    private func dust(on orbit: Orbit, half: Half, opacity: Double, ambient: TimeInterval, in canvas: inout GraphicsContext) {
        guard opacity > 0.01 else { return }
        for index in 0..<orbit.dust {
            let theta = Double(index) / Double(orbit.dust) * 2 * .pi + ambient / 80 * 2 * .pi + Double(index % 3) * 0.07
            guard (sin(theta) < 0) == (half == .back) else { continue }
            let twinkle = 0.5 + 0.5 * sin(ambient * 1.7 + Double(index) * 2.3)
            let point = point(on: orbit, at: theta)
            canvas.fill(disc(point, 0.7 + 0.4 * twinkle), with: .color(orbit.color.opacity(opacity * (0.35 + 0.65 * twinkle))))
        }
    }

    private func point(on orbit: Orbit, at theta: Double) -> CGPoint {
        CGPoint(x: cos(theta) * orbit.width / 2, y: sin(theta) * orbit.height / 2)
    }

    private func angle(of traveller: Traveller, at time: TimeInterval) -> Double {
        traveller.start + 2 * .pi * time / traveller.period
    }

    /// The upper half of its orbit is the far side.
    private func isBehind(_ traveller: Traveller, at time: TimeInterval) -> Bool {
        sin(angle(of: traveller, at: time)) < 0
    }

    /// A small planet with its glow and a short trail behind it on its orbit.
    private func draw(_ traveller: Traveller, at time: TimeInterval, opacity: Double, in canvas: inout GraphicsContext) {
        guard opacity > 0.01 else { return }
        let orbit = Self.orbits[traveller.orbit]
        let theta = angle(of: traveller, at: time)
        let fade = isBehind(traveller, at: time) ? 0.75 : 1
        for step in 1...10 {
            let behind = point(on: orbit, at: theta - Double(step) * 0.035)
            let left = 1 - Double(step) / 11
            canvas.fill(disc(behind, traveller.size / 2 * 0.55 * left), with: .color(traveller.color.opacity(0.4 * left * opacity * fade)))
        }
        let centre = point(on: orbit, at: theta)
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: traveller.color.opacity(0.85), radius: 5))
            layer.fill(disc(centre, traveller.size / 2), with: .color(traveller.color.opacity(opacity * fade)))
        }
        canvas.fill(
            disc(CGPoint(x: centre.x - traveller.size * 0.15, y: centre.y - traveller.size * 0.15), traveller.size * 0.18),
            with: .color(.white.opacity(0.55 * opacity * fade))
        )
    }

    private func disc(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }
}
