//
//  FirstStarScene.swift
//  Cue Studio
//

import SwiftUI

/// What 1.7 draws on the 390 × 844 frame of the board, as a pure function of the story's time and the world's time: the three tilted orbits with their
/// planets, YOU, the comet and its sparkles, the star with its burst, rings, cross and halo, the line from YOU, the dust and the label. On top of
/// the board (the owner's pass): where the take folds, a lens flare and a shockwave; the comet leaves the first flight's trail (`StarRibbon`);
/// the universe holds its breath before the star lights, a bloom as it does, a wave of light across the orbits and YOU pulsing; a bead of light
/// draws the line; the lit star keeps glinting, and once the story rests a shooting star crosses the sky now and then.
struct FirstStarScene: View {
    /// Seconds into the story (held at `FirstStarScript.hold` once it has played).
    let story: Double
    /// Seconds since the screen came up (the orbits and YOU keep going after the story rests).
    let world: Double
    let reduceMotion: Bool

    var body: some View {
        Canvas { canvas, _ in
            drawShootingStar(&canvas)
            var universe = canvas
            universe.opacity = FirstStarScript.universeLight(at: story)
            drawOrbits(&universe)
            drawCore(&universe)
            drawLine(&canvas)
            drawFold(&canvas)
            drawComet(&canvas)
            drawStar(&canvas)
            drawDust(&canvas)
        }
        .overlay(alignment: .topLeading) { label }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Orbits and YOU

    private func drawOrbits(_ canvas: inout GraphicsContext) {
        let core = FirstStarScript.core
        let flat = FirstStarScript.flatten
        for orbit in FirstStarScript.orbits {
            let radius = orbit.radius
            let ring = Path(ellipseIn: CGRect(x: -radius, y: -radius * flat, width: radius * 2, height: radius * 2 * flat))
                .applying(CGAffineTransform(rotationAngle: FirstStarScript.tilt.radians))
                .applying(CGAffineTransform(translationX: core.x, y: core.y))
            let wave = FirstStarScript.orbitWave(radius: radius, at: story)
            canvas.stroke(ring, with: .color(rim(orbit.tone)), lineWidth: 1)
            if wave > 0.01 {
                canvas.drawLayer { layer in
                    layer.addFilter(.shadow(color: world(orbit.tone).opacity(0.9 * wave), radius: 6))
                    layer.stroke(ring, with: .color(world(orbit.tone).opacity(0.85 * wave)), lineWidth: 1 + 1.4 * wave)
                }
            }
            let point = FirstStarScript.planet(orbit, at: reduceMotion ? 0 : world)
            let size = orbit.planet
            glow(&canvas, at: point, radius: size, colors: [world(orbit.tone).opacity(0.5), world(orbit.tone).opacity(0)], inner: size / 2)
            let highlight = CGPoint(x: point.x - size * 0.16, y: point.y - size * 0.2)
            canvas.fill(
                LightFX.disc(point, size / 2),
                with: .radialGradient(stops(sphere(orbit.tone), at: [0, 0.45, 1]), center: highlight, startRadius: 0, endRadius: size * 0.9)
            )
        }
    }

    private func drawCore(_ canvas: inout GraphicsContext) {
        let center = FirstStarScript.core
        let pulse = (reduceMotion ? 0 : FirstStarScript.breath(at: world, period: 3)) + 1.4 * FirstStarScript.youPulse(at: story)
        // The board's `box-shadow`s on the 22 pt ball (`core`, 3 s): a wide violet one under a tight white one, both swelling together.
        light(&canvas, at: center, reach: 11 + 20 + 12 * pulse, blur: 60 + 24 * pulse, color: Palette.Universe.nightViolet.opacity(0.45 + 0.15 * pulse))
        light(&canvas, at: center, reach: 11 + 6 + 4 * pulse, blur: 18 + 8 * pulse, color: .white.opacity(0.5 + 0.2 * pulse))
        let ball = stops(Palette.World.youCore, at: [0, 0.5, 1])
        canvas.fill(LightFX.disc(center, 11), with: .radialGradient(ball, center: center, startRadius: 0, endRadius: 11))
    }

    /// A CSS `box-shadow` of a disc: the ball grown by its spread (`reach` is that radius), blurred by half its blur value.
    private func light(_ canvas: inout GraphicsContext, at center: CGPoint, reach: Double, blur: Double, color: Color) {
        canvas.drawLayer { layer in
            layer.addFilter(.blur(radius: blur / 2))
            layer.fill(LightFX.disc(center, reach), with: .color(color))
        }
    }

    // MARK: - The line, the comet and the star

    private func drawLine(_ canvas: inout GraphicsContext) {
        let drawn = FirstStarScript.line(at: story)
        guard drawn > 0 else { return }
        var line = Path()
        line.move(to: FirstStarScript.core)
        line.addLine(to: FirstStarScript.star)
        canvas.stroke(
            line.trimmedPath(from: 0, to: drawn),
            with: .linearGradient(
                Gradient(colors: [Palette.Universe.starLilac.opacity(0.5), Palette.Universe.starGold.opacity(0.55)]),
                startPoint: FirstStarScript.core, endPoint: FirstStarScript.star
            ),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
        )
        // A bead of light draws it, and goes out into the star.
        guard drawn < 1 else { return }
        let core = FirstStarScript.core
        let star = FirstStarScript.star
        let bead = CGPoint(x: core.x + (star.x - core.x) * drawn, y: core.y + (star.y - core.y) * drawn)
        glow(&canvas, at: bead, radius: 9, colors: [Palette.Universe.starCream.opacity(0.9), Palette.acc.opacity(0)], inner: 0)
        canvas.fill(LightFX.disc(bead, 1.8), with: .color(.white))
    }

    /// Where the take becomes light: a horizontal lens flare (a thinner upright one with it) and a shockwave ring.
    private func drawFold(_ canvas: inout GraphicsContext) {
        let fold = FirstStarScript.fold(at: story)
        let center = FirstStarScript.routeStart
        if fold.flareOpacity > 0.01 {
            let fade = Gradient(stops: [
                .init(color: Palette.acc.opacity(0), location: 0), .init(color: Palette.Universe.starCream.opacity(0.7 * fold.flareOpacity), location: 0.4),
                .init(color: Color.white.opacity(fold.flareOpacity), location: 0.5),
                .init(color: Palette.Universe.starCream.opacity(0.7 * fold.flareOpacity), location: 0.6), .init(color: Palette.acc.opacity(0), location: 1),
            ])
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.acc.opacity(0.8 * fold.flareOpacity), radius: 5))
                let wide = fold.flare
                layer.fill(
                    Path(roundedRect: CGRect(x: center.x - wide, y: center.y - 1.3, width: wide * 2, height: 2.6), cornerRadius: 1.3),
                    with: .linearGradient(fade, startPoint: CGPoint(x: center.x - wide, y: center.y), endPoint: CGPoint(x: center.x + wide, y: center.y))
                )
                let tall = fold.flare * 0.32
                layer.fill(
                    Path(roundedRect: CGRect(x: center.x - 0.8, y: center.y - tall, width: 1.6, height: tall * 2), cornerRadius: 0.8),
                    with: .linearGradient(fade, startPoint: CGPoint(x: center.x, y: center.y - tall), endPoint: CGPoint(x: center.x, y: center.y + tall))
                )
            }
        }
        if fold.waveOpacity > 0.01 {
            canvas.stroke(LightFX.disc(center, fold.wave), with: .color(Palette.Universe.starCream.opacity(fold.waveOpacity)), lineWidth: 1.4)
        }
    }

    private func drawComet(_ canvas: inout GraphicsContext) {
        let comet = FirstStarScript.comet(at: story)
        let trail = StarRibbon.trail(at: story, length: 0.4) { FirstStarScript.cometHead(at: $0) }
        StarRibbon.draw(trail, width: 5, in: &canvas)
        if comet.orb > 0 {
            let point = FirstStarScript.route(comet.head)
            let orb = Gradient(stops: [
                .init(color: Palette.Universe.starCream.opacity(comet.orb), location: 0.16), .init(color: Palette.acc.opacity(0.6 * comet.orb), location: 0.32),
                .init(color: Palette.acc.opacity(0), location: 0.7),
            ])
            canvas.fill(LightFX.disc(point, 17), with: .radialGradient(orb, center: point, startRadius: 0, endRadius: 17))
            StarRibbon.head(at: point, opacity: comet.orb, spin: story, in: &canvas)
        }
        let flash = FirstStarScript.glow(at: story)
        if flash.opacity > 0 {
            let center = FirstStarScript.routeStart
            let radius = 30 * flash.scale
            let gradient = Gradient(stops: [
                .init(color: Palette.Universe.starCream.opacity(flash.opacity), location: 0),
                .init(color: Palette.acc.opacity(0.6 * flash.opacity), location: 0.35),
                .init(color: Palette.acc.opacity(0), location: 1),
            ])
            canvas.fill(LightFX.disc(center, radius), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
        }
        for item in FirstStarScript.sparkles {
            let pose = FirstStarScript.sparkle(item, at: story)
            guard pose.opacity > 0 else { continue }
            let center = CGPoint(x: item.origin.x, y: item.origin.y + pose.drop)
            canvas.fill(Self.fourPointStar(center: center, size: 10 * pose.scale), with: .color(Palette.Universe.starGold.opacity(pose.opacity)))
        }
    }

    private func drawStar(_ canvas: inout GraphicsContext) {
        let bloom = FirstStarScript.bloom(at: story)
        if bloom.opacity > 0.01 {
            let colors = [Color.white.opacity(bloom.opacity), Palette.Universe.starGold.opacity(0.55 * bloom.opacity), Palette.acc.opacity(0)]
            canvas.fill(
                LightFX.disc(FirstStarScript.star, bloom.radius),
                with: .radialGradient(stops(colors, at: [0, 0.25, 1]), center: FirstStarScript.star, startRadius: 0, endRadius: bloom.radius)
            )
        }
        drawBurst(&canvas)
        let star = FirstStarScript.star
        for ring in FirstStarScript.rings(at: story) where ring.opacity > 0.01 {
            let color = ring.isGold ? Palette.acc : Palette.Universe.starCream.opacity(0.85)
            canvas.stroke(LightFX.disc(star, 20 * ring.scale), with: .color(color.opacity(ring.opacity)), lineWidth: ring.width)
        }
        drawCross(&canvas)
        let pose = FirstStarScript.starPose(at: story)
        guard pose.opacity > 0.01 else { return }
        let breath = reduceMotion ? 0.5 : FirstStarScript.breath(at: world, period: 2.4)
        let glint = reduceMotion ? 0 : FirstStarScript.starGlint(at: world)
        let halo = 20 * pose.scale * (1 + 0.4 * breath + 0.5 * glint)
        let strength = 0.45 * (0.22 + 0.18 * breath) / 0.4 * pose.opacity
        glow(&canvas, at: star, radius: halo, colors: [Palette.acc.opacity(strength), Palette.acc.opacity(0)], inner: 0)
        canvas.fill(Self.fourPointStar(center: star, size: 20 * pose.scale * (1 + 0.12 * breath)), with: .color(Palette.acc.opacity(pose.opacity)))
        canvas.fill(LightFX.disc(star, 2.2 * pose.scale), with: .color(Palette.Universe.starCream.opacity(pose.opacity * (0.7 + 0.3 * glint))))
    }

    /// The ten specks that fly out as the star lights.
    private func drawBurst(_ canvas: inout GraphicsContext) {
        let star = FirstStarScript.star
        let burst = FirstStarScript.burst(at: story)
        guard burst.opacity > 0 else { return }
        for (index, end) in FirstStarScript.burst.enumerated() {
            let center = CGPoint(x: star.x + end.x * burst.progress, y: star.y + end.y * burst.progress)
            let color = (index.isMultiple(of: 2) ? Color.white : Palette.Universe.starGold).opacity(burst.opacity)
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: color, radius: 3.5))
                layer.fill(LightFX.disc(center, 2 * (1 - 0.7 * burst.progress)), with: .color(color))
            }
        }
    }

    /// The cross of light that flares on the star and settles small.
    private func drawCross(_ canvas: inout GraphicsContext) {
        let star = FirstStarScript.star
        let cross = FirstStarScript.cross(at: story)
        guard cross.opacity > 0.01, cross.scale > 0.01 else { return }
        // It turns slowly, and grows for a moment with each glint of the star.
        let glint = reduceMotion ? 0 : FirstStarScript.starGlint(at: world)
        let reach = cross.scale + 0.25 * glint
        let halfWide = 85 * reach
        let halfTall = 59.5 * reach
        let fade = Gradient(stops: [
            .init(color: Palette.Universe.starGold.opacity(0), location: 0),
            .init(color: Palette.Universe.starGold.opacity(0.4 * cross.opacity), location: 0.3),
            .init(color: Palette.Universe.starGold.opacity(cross.opacity), location: 0.5),
            .init(color: Palette.Universe.starGold.opacity(0.4 * cross.opacity), location: 0.7),
            .init(color: Palette.Universe.starGold.opacity(0), location: 1),
        ])
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: Palette.acc.opacity(0.9), radius: 3))
            layer.translateBy(x: star.x, y: star.y)
            layer.rotate(by: .degrees(reduceMotion ? 0 : world * 5))
            layer.translateBy(x: -star.x, y: -star.y)
            // The thin diagonal spikes of a lens, with the cross.
            let spike = halfTall * 0.55
            for angle in [45.0, -45.0] {
                var diagonal = layer
                diagonal.translateBy(x: star.x, y: star.y)
                diagonal.rotate(by: .degrees(angle))
                diagonal.fill(
                    Path(CGRect(x: -spike, y: -0.5, width: spike * 2, height: 1)),
                    with: .linearGradient(fade, startPoint: CGPoint(x: -spike, y: 0), endPoint: CGPoint(x: spike, y: 0))
                )
            }
            layer.fill(
                Path(CGRect(x: star.x - halfWide, y: star.y - 0.9, width: halfWide * 2, height: 1.8)),
                with: .linearGradient(fade, startPoint: CGPoint(x: star.x - halfWide, y: star.y), endPoint: CGPoint(x: star.x + halfWide, y: star.y))
            )
            layer.fill(
                Path(CGRect(x: star.x - 0.9, y: star.y - halfTall, width: 1.8, height: halfTall * 2)),
                with: .linearGradient(fade, startPoint: CGPoint(x: star.x, y: star.y - halfTall), endPoint: CGPoint(x: star.x, y: star.y + halfTall))
            )
        }
    }

    /// Once the story rests, now and then a shooting star crosses the sky above the universe, with the first flight's trail.
    private func drawShootingStar(_ canvas: inout GraphicsContext) {
        guard !reduceMotion, FirstStarScript.shootingStar(at: world) != nil || FirstStarScript.shootingStar(at: world - 0.3) != nil else { return }
        let trail = StarRibbon.trail(at: world, length: 0.3) { second in
            FirstStarScript.shootingStar(at: second) ?? (CGPoint(x: 120, y: 124), 0)
        }
        StarRibbon.draw(trail, width: 2.6, in: &canvas)
        if let head = FirstStarScript.shootingStar(at: world) {
            StarRibbon.head(at: head.point, opacity: 0.85 * head.opacity, spin: world, radius: 2.6, in: &canvas)
        }
    }

    private func drawDust(_ canvas: inout GraphicsContext) {
        for item in FirstStarScript.dust {
            let pose = FirstStarScript.dust(item, at: story)
            guard pose.opacity > 0.01 else { continue }
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.acc.opacity(pose.opacity), radius: 2))
                layer.fill(
                    LightFX.disc(CGPoint(x: item.origin.x, y: item.origin.y + pose.drop), 1),
                    with: .color(Palette.Universe.starGold.opacity(pose.opacity))
                )
            }
        }
    }

    // MARK: - Drawing helpers

    private func glow(_ canvas: inout GraphicsContext, at center: CGPoint, radius: Double, colors: [Color], inner: Double, reach: Double? = nil) {
        canvas.fill(
            LightFX.disc(center, radius),
            with: .radialGradient(Gradient(colors: colors), center: center, startRadius: inner, endRadius: reach ?? radius)
        )
    }

    private func stops(_ colors: [Color], at locations: [Double]) -> Gradient {
        Gradient(stops: zip(colors, locations).map { Gradient.Stop(color: $0, location: $1) })
    }

    /// "FIRST TAKE · TODAY", centered over the star.
    private var label: some View {
        let pose = FirstStarScript.label(at: story)
        return Text("FIRST TAKE · TODAY")
            .monoFont(size: 9.5, weight: .semibold)
            .interfaceTracking(1.33)
            .foregroundStyle(Palette.Universe.starGold)
            .fixedSize()
            .frame(width: 160)
            .opacity(pose.opacity)
            .offset(x: 176, y: 150 + pose.lift)
    }

    // MARK: - Pieces

    /// The four-pointed star the board draws (`M12 1C12.9 8.4 15.6 11.1 23 12 …` in a 24 box), `size` points across.
    static func fourPointStar(center: CGPoint, size: Double) -> Path {
        let unit = size / 24
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: center.x + (x - 12) * unit, y: center.y + (y - 12) * unit) }
        var path = Path()
        path.move(to: point(12, 1))
        path.addCurve(to: point(23, 12), control1: point(12.9, 8.4), control2: point(15.6, 11.1))
        path.addCurve(to: point(12, 23), control1: point(15.6, 12.9), control2: point(12.9, 15.6))
        path.addCurve(to: point(1, 12), control1: point(11.1, 15.6), control2: point(8.4, 12.9))
        path.addCurve(to: point(12, 1), control1: point(8.4, 11.1), control2: point(11.1, 8.4))
        path.closeSubpath()
        return path
    }

    private func world(_ tone: FirstStarScript.Tone) -> Color {
        switch tone {
        case .pink: Palette.World.pink
        case .mint: Palette.World.mint
        case .warm: Palette.World.warm
        }
    }

    private func sphere(_ tone: FirstStarScript.Tone) -> [Color] {
        switch tone {
        case .pink: Palette.World.pinkSphere
        case .mint: Palette.World.mintSphere
        case .warm: Palette.World.warmSphere
        }
    }

    /// The orbit's line, at the board's opacity for each world.
    private func rim(_ tone: FirstStarScript.Tone) -> Color {
        switch tone {
        case .pink: Palette.World.pink.opacity(0.3)
        case .mint: Palette.World.mint.opacity(0.28)
        case .warm: Palette.World.warm.opacity(0.32)
        }
    }
}
