//
//  UltraConsentHero.swift
//  Cue Studio
//

import SwiftUI

/// The top of Ultra AI's permission sheet: its ✦ in a galaxy, opening as the sheet comes up (owner, 02/11/2026: an invitation that makes the
/// creator want to try it, in the first flight's finish). A violet nebula with a warm drift fades in, three tilted orbits draw themselves
/// round the centre (Ultra AI's violet and gold, `Palette.Scripts.ultraGlow`), and at `ignition` the ✦ ignites (small and turned, then past
/// its size and back) with a flash, a ring and six sparks, and Core Haptics' `ultraIgnite`; then two moons ride the orbits with the first
/// flight's short tail (`StarRibbon`), the ✦ breathes its glow under a slow cross of light and the stars twinkle. The light always fits
/// inside the drawing, so nothing is cut. Decorative. Under Reduce Motion it shows the settled galaxy and nothing moves.
struct UltraConsentHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearedAt = Date.now

    static let height: CGFloat = 232
    /// The second the ✦ ignites (the sheet has come up by then).
    static let ignition = 0.55
    /// The opening is over: everything from here is the galaxy's own slow motion.
    static let settled = 2.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let time = reduceMotion ? Self.settled : context.date.timeIntervalSince(appearedAt)
            ZStack {
                Canvas { canvas, size in
                    Self.draw(in: &canvas, size: size, time: time)
                }
                star(at: time)
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .onAppear { appearedAt = .now }
        .task {
            guard !reduceMotion else { return }
            HapticPatterns.prewarm()
            try? await Task.sleep(for: .seconds(Self.ignition))
            guard !Task.isCancelled else { return }
            HapticPatterns.playUltraIgnite()
        }
        .accessibilityHidden(true)
    }

    // MARK: - The ✦

    /// The ✦: nothing before `ignition`, then a spring from small and turned to past its size and back; its glow breathes once settled.
    private func star(at time: Double) -> some View {
        let lit = Self.spring(time - Self.ignition)
        let breath = time > Self.settled ? (sin((time - Self.settled) * 1.6 - .pi / 2) + 1) / 2 : 0
        return Text(verbatim: "✦")
            .cueFont(54, weight: .bold)
            .foregroundStyle(Palette.aiTextStrong)
            .shadow(color: Palette.aiText.opacity(0.6 + 0.25 * breath), radius: 16 + 10 * breath)
            .shadow(color: Palette.Universe.starGold.opacity(0.18 * breath), radius: 30)
            .scaleEffect(0.2 + 0.8 * lit)
            .rotationEffect(.degrees(-70 * (1 - lit)))
            .opacity(min(1, max(0, (time - Self.ignition) / 0.12)))
    }

    /// A spring from 0 to 1 that passes 1 once and settles (`seconds` since it started; 0 before).
    private static func spring(_ seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        return 1 - exp(-6 * seconds) * cos(9 * seconds)
    }

    private static func smooth(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    // MARK: - The galaxy

    /// An orbit: its tilt, its half-width as a share of the width and half-height as a share of the height, how fast its moon goes (turns a
    /// second), where the moon starts (radians), the moon's tail colours (nil: no moon), and the second it starts to draw itself.
    private struct Orbit {
        let tilt: Double
        let width: CGFloat
        let height: CGFloat
        let speed: Double
        let phase: Double
        let moon: [Color]?
        let drawsFrom: Double
    }

    private static let orbits = [
        Orbit(tilt: 5, width: 0.47, height: 0.4, speed: 0, phase: 0, moon: nil, drawsFrom: 0.35),
        Orbit(
            tilt: -18, width: 0.4, height: 0.21, speed: 0.08, phase: 2.6,
            moon: [.white, Palette.aiTextStrong, Palette.aiText, Palette.Scripts.ultraStarGlow], drawsFrom: 0.1
        ),
        Orbit(tilt: 24, width: 0.3, height: 0.15, speed: -0.11, phase: 5.2, moon: StarRibbon.starlight, drawsFrom: 0.22),
    ]

    /// Where the twinkling stars sit, as shares of the width and height, their phase, and whether they are gold.
    private static let sparkles: [(x: CGFloat, y: CGFloat, phase: Double, gold: Bool)] = [
        (0.14, 0.2, 0, false), (0.84, 0.16, 1.3, true), (0.24, 0.84, 2.1, false), (0.76, 0.88, 0.7, false), (0.93, 0.5, 2.8, false),
        (0.06, 0.56, 1.9, true), (0.36, 0.08, 3.4, false), (0.62, 0.94, 4.1, true), (0.55, 0.1, 0.4, false), (0.42, 0.9, 5.0, false),
    ]

    private static func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let opening = smooth(time / 0.8)
        drawNebula(in: &canvas, size: size, center: center, time: time, opening: opening)
        for sparkle in sparkles {
            let twinkle = (sin(time * 2.2 + sparkle.phase) + 1) / 2
            let point = CGPoint(x: size.width * sparkle.x, y: size.height * sparkle.y)
            let color = sparkle.gold ? Palette.Universe.starGold : Palette.aiTextStrong
            canvas.fill(LightFX.disc(point, 0.9 + 0.8 * twinkle), with: .color(color.opacity((0.3 + 0.5 * twinkle) * opening)))
        }
        // A slow cross of light behind the ✦ once it has ignited.
        let after = time - ignition
        if after > 0 {
            LightFX.cross(
                at: center, size: 110, thickness: 1.2, verticalRatio: 0.75,
                pose: MotionPose(opacity: 0.32 * smooth(after / 0.6), rot: time * 6), color: Palette.aiTextStrong,
                glow: Palette.aiText.opacity(0.8), in: &canvas
            )
        }
        for orbit in orbits { drawOrbit(orbit, in: &canvas, size: size, center: center, time: time) }
        drawIgnition(in: &canvas, size: size, center: center, time: time)
    }

    /// A violet glow round the centre and a faint warm one drifting beside it, each small enough to fade out inside the drawing.
    private static func drawNebula(in canvas: inout GraphicsContext, size: CGSize, center: CGPoint, time: Double, opening: Double) {
        let reach = min(size.width, size.height) / 2
        canvas.fill(
            LightFX.disc(center, reach),
            with: .radialGradient(
                Gradient(colors: [Palette.aiText.opacity(0.34 * opening), Palette.aiText.opacity(0.1 * opening), Palette.aiText.opacity(0)]),
                center: center, startRadius: 0, endRadius: reach
            )
        )
        let warm = CGPoint(x: center.x + reach * 0.35 * cos(time * 0.25), y: center.y + reach * 0.18 * sin(time * 0.25))
        canvas.fill(
            LightFX.disc(warm, reach * 0.55),
            with: .radialGradient(
                Gradient(colors: [Palette.Universe.starGold.opacity(0.1 * opening), Palette.Universe.starGold.opacity(0)]),
                center: warm, startRadius: 0, endRadius: reach * 0.55
            )
        )
    }

    /// Where `orbit`'s ellipse is at `angle` (radians), on the canvas.
    private static func point(on orbit: Orbit, at angle: Double, size: CGSize, center: CGPoint) -> CGPoint {
        let x = size.width * orbit.width * cos(angle)
        let y = size.height * orbit.height * sin(angle)
        let tilt = orbit.tilt * .pi / 180
        return CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt), y: center.y + x * sin(tilt) + y * cos(tilt))
    }

    /// The orbit draws itself round in 0.75 s from `drawsFrom` with a bright tip, its colours turning slowly; its moon comes in once it is
    /// whole, nearer (bigger, brighter) on the lower half.
    private static func drawOrbit(_ orbit: Orbit, in canvas: inout GraphicsContext, size: CGSize, center: CGPoint, time: Double) {
        let drawn = smooth((time - orbit.drawsFrom) / 0.75)
        guard drawn > 0.001 else { return }
        let steps = max(2, Int(120 * drawn))
        var path = Path()
        for step in 0...steps {
            let point = point(on: orbit, at: 2 * .pi * drawn * Double(step) / Double(steps), size: size, center: center)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        let faint = orbit.moon == nil ? 0.28 : 0.55
        canvas.stroke(
            path,
            with: .conicGradient(
                Gradient(colors: Palette.Scripts.ultraGlow.map { $0.opacity(faint) }), center: center, angle: .radians(time * 0.35)
            ),
            lineWidth: orbit.moon == nil ? 0.8 : 1.2
        )
        if drawn < 0.999 {
            let tip = point(on: orbit, at: 2 * .pi * drawn, size: size, center: center)
            canvas.fill(LightFX.disc(tip, 2.2), with: .color(Palette.aiTextStrong.opacity(0.9)))
            canvas.fill(
                LightFX.disc(tip, 9),
                with: .radialGradient(Gradient(colors: [Palette.aiText.opacity(0.5), Palette.aiText.opacity(0)]), center: tip, startRadius: 0, endRadius: 9)
            )
        }
        guard let colors = orbit.moon else { return }
        let shows = smooth((time - orbit.drawsFrom - 0.75) / 0.4)
        guard shows > 0.01 else { return }
        let angle = { (second: Double) in orbit.phase + 2 * .pi * orbit.speed * second }
        let trail = StarRibbon.trail(at: time, length: 0.9) { second in
            (point(on: orbit, at: angle(second), size: size, center: center), shows)
        }
        StarRibbon.draw(trail, colors: colors, width: 2.4, in: &canvas)
        let near = (sin(angle(time)) + 1) / 2
        let moon = point(on: orbit, at: angle(time), size: size, center: center)
        let radius = 2.6 + 1.2 * near
        let halo = colors[1]
        canvas.fill(
            LightFX.disc(moon, radius * 3.4),
            with: .radialGradient(
                Gradient(colors: [halo.opacity(0.4 * shows), halo.opacity(0)]), center: moon, startRadius: 0, endRadius: radius * 3.4
            )
        )
        canvas.fill(LightFX.disc(moon, radius), with: .color(Color.white.opacity((0.7 + 0.3 * near) * shows)))
    }

    /// The ✦ igniting: a flash, a ring that opens to the galaxy's edge, and six sparks that fly out and fade, in the second after `ignition`.
    private static func drawIgnition(in canvas: inout GraphicsContext, size: CGSize, center: CGPoint, time: Double) {
        let progress = (time - ignition) / 1.0
        guard progress > 0, progress < 1 else { return }
        let fade = (1 - progress) * (1 - progress)
        let flash = 14 + 60 * smooth(progress * 2)
        canvas.fill(
            LightFX.disc(center, flash),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.7 * fade), Palette.aiText.opacity(0.35 * fade), Palette.aiText.opacity(0)]),
                center: center, startRadius: 0, endRadius: flash
            )
        )
        let eased = 1 - pow(1 - progress, 3)
        let reach = min(size.width, size.height) / 2 - 4
        canvas.stroke(
            LightFX.disc(center, 18 + (reach - 18) * eased), with: .color(Palette.aiTextStrong.opacity(0.75 * fade)),
            lineWidth: 0.6 + 1.2 * (1 - progress)
        )
        for index in 0..<6 {
            let direction = (30 + 60 * Double(index)) * .pi / 180
            let distance = 22 + 64 * eased
            let length = 9 * (1 - progress)
            let tip = CGPoint(x: center.x + distance * cos(direction), y: center.y + distance * sin(direction))
            let tail = CGPoint(x: tip.x - length * cos(direction), y: tip.y - length * sin(direction))
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: tip)
            let color = index.isMultiple(of: 2) ? Palette.aiTextStrong : Palette.Universe.starGold
            canvas.stroke(streak, with: .color(color.opacity(0.9 * fade)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }
}

#if DEBUG
#Preview {
    UltraConsentHero()
        .background(Palette.bg)
}
#endif
