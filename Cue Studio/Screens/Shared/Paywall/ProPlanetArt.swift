//
//  ProPlanetArt.swift
//  Cue Studio
//

import SwiftUI

/// "You are the main planet" (09, Pro art): a 60 pt golden planet in a soft gold atmosphere, two orbits tilted −7° that pass behind it and in front of it
/// (radii 96 × 17 warm and 150 × 24 lavender, so 192 × 34 and 300 × 48 across), three small platform planets travelling them (TikTok and Reels on the
/// outer one, 26 s; Shorts on the inner one, 17 s) and a faint band of light drifting across the planet (9 s). No photo, no face. Still under Reduce Motion.
struct ProPlanetArt: View {
    /// The planet's ignition on the opening (opacity and scale); the pose of a finished opening is 1 and 1.
    var ignition = Pose()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Orbit {
        let width: CGFloat
        let height: CGFloat
        let color: Color
    }

    private struct Traveller {
        let orbit: Int
        let size: CGFloat
        let color: Color
        let period: Double
        let start: Double
    }

    private static let tilt = Angle.degrees(-7)
    private static let planetRadius: CGFloat = 30

    private static let orbits = [
        Orbit(width: 192, height: 34, color: Palette.World.warm.opacity(0.45)),
        Orbit(width: 300, height: 48, color: Palette.aiTextStrong.opacity(0.35)),
    ]

    private static let travellers = [
        Traveller(orbit: 1, size: 11, color: Palette.Platform.tikTok, period: 26, start: 0.2),
        Traveller(orbit: 1, size: 8, color: Palette.Platform.reels, period: 26, start: 3.4),
        Traveller(orbit: 0, size: 7, color: Palette.Platform.shorts, period: 17, start: 1.1),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let centre = CGPoint(x: size.width / 2, y: 82)
        var layer = canvas
        layer.opacity = ignition.opacity
        layer.translateBy(x: centre.x, y: centre.y)
        layer.scaleBy(x: ignition.scale, y: ignition.scale)
        // The atmosphere.
        layer.fill(
            Path(ellipseIn: CGRect(x: -96, y: -96, width: 192, height: 192)),
            with: .radialGradient(Gradient(colors: [Palette.World.warm.opacity(0.34), .clear]), center: .zero, startRadius: 0, endRadius: 96)
        )
        // What is behind the planet: the far half of each orbit and the travellers on it.
        layer.drawLayer { behind in
            behind.rotate(by: Self.tilt)
            for orbit in Self.orbits { stroke(orbit, half: .back, in: &behind) }
            for traveller in Self.travellers where isBehind(traveller, at: time) { draw(traveller, at: time, in: &behind) }
        }
        planet(in: &layer, time: time)
        layer.drawLayer { front in
            front.rotate(by: Self.tilt)
            for orbit in Self.orbits { stroke(orbit, half: .front, in: &front) }
            for traveller in Self.travellers where !isBehind(traveller, at: time) { draw(traveller, at: time, in: &front) }
        }
    }

    // MARK: - The planet

    private func planet(in canvas: inout GraphicsContext, time: TimeInterval) {
        let radius = Self.planetRadius
        let disc = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: Palette.World.warm.opacity(0.4), radius: 14))
            layer.fill(disc, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Palette.Universe.proPlanetLight, location: 0), .init(color: Palette.Universe.proPlanetMid, location: 0.32),
                    .init(color: Palette.Universe.proPlanetShade, location: 0.66), .init(color: Palette.Universe.proPlanetDark, location: 1),
                ]),
                center: CGPoint(x: -radius * 0.4, y: -radius * 0.4), startRadius: 0, endRadius: radius * 1.7
            ))
        }
        canvas.stroke(disc, with: .color(Palette.Universe.proPlanetLight.opacity(0.35)), lineWidth: 0.6)
        // A faint band of light crossing it every 9 s.
        let cycle = time.truncatingRemainder(dividingBy: 9) / 9
        canvas.drawLayer { layer in
            layer.clip(to: disc)
            layer.rotate(by: .degrees(20))
            let x = -radius * 2 + cycle * radius * 4
            layer.fill(
                Path(CGRect(x: x - 7, y: -radius * 1.5, width: 14, height: radius * 3)),
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0), .white.opacity(0.18), .white.opacity(0)]),
                    startPoint: CGPoint(x: x - 7, y: 0), endPoint: CGPoint(x: x + 7, y: 0)
                )
            )
        }
    }

    // MARK: - Orbits

    private enum Half { case back, front }

    private func stroke(_ orbit: Orbit, half: Half, in canvas: inout GraphicsContext) {
        // The far half is the upper arc of the ellipse (y up the screen is negative), the near half the lower.
        let first = half == .back ? Double.pi : 0
        var path = Path()
        for step in 0...48 {
            let theta = first + Double.pi * Double(step) / 48
            let point = CGPoint(x: cos(theta) * orbit.width / 2, y: sin(theta) * orbit.height / 2)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        canvas.stroke(path, with: .color(orbit.color), lineWidth: 1)
    }

    private func angle(of traveller: Traveller, at time: TimeInterval) -> Double {
        traveller.start + 2 * .pi * time / traveller.period
    }

    /// The upper half of its orbit is the far side.
    private func isBehind(_ traveller: Traveller, at time: TimeInterval) -> Bool {
        sin(angle(of: traveller, at: time)) < 0
    }

    private func draw(_ traveller: Traveller, at time: TimeInterval, in canvas: inout GraphicsContext) {
        let orbit = Self.orbits[traveller.orbit]
        let theta = angle(of: traveller, at: time)
        let point = CGPoint(x: cos(theta) * orbit.width / 2, y: sin(theta) * orbit.height / 2)
        let radius = traveller.size / 2
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: traveller.color.opacity(0.8), radius: 4))
            let disc = CGRect(x: point.x - radius, y: point.y - radius, width: traveller.size, height: traveller.size)
            layer.fill(Path(ellipseIn: disc), with: .color(traveller.color))
        }
    }
}
