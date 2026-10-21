//
//  WelcomeStarPainter.swift
//  Cue Studio
//

import SwiftUI

/// Draws the welcome's star scene at one second of `WelcomeScript` (09 §12): the C's line and dots, the dust, rings, flares and sparks,
/// the star with its trail, and the explosion on the sixth dot. Everything is a pose read from a track at `time`; the lit dots keep shining
/// after the story ends, so their shine reads `ambient` (the seconds since the opening began, past its end).
struct WelcomeStarPainter {
    let time: Double
    let ambient: Double
    /// Where the star goes after the C, which depends on where the three words are on this screen.
    let starPath: PoseTrack

    func paint(in context: inout GraphicsContext) {
        drawLines(in: &context)
        drawDust(in: &context)
        for (index, dot) in WelcomeScript.dots.enumerated() { drawDot(dot, index: index, in: &context) }
        drawSparks(in: &context)
        drawExplosion(in: &context)
        drawStar(in: &context)
    }

    // MARK: - The C

    private func drawLines(in context: inout GraphicsContext) {
        let dots = WelcomeScript.dots
        var line = Path()
        line.move(to: dots[0].point)
        for dot in dots.dropFirst() { line.addLine(to: dot.point) }
        let drawn = WelcomeScript.line.pose(at: time).scale
        if drawn > 0 {
            context.stroke(
                line.trimmedPath(from: 0, to: drawn), with: .color(Palette.aiTextStrong.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
        }
        let leg = WelcomeScript.leg.pose(at: time).scale
        if leg > 0, let last = dots.last {
            var path = Path()
            path.move(to: last.point)
            path.addLine(to: WelcomeScript.cue)
            context.stroke(path.trimmedPath(from: 0, to: leg), with: .color(Palette.acc.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        let dim = WelcomeScript.dimCue.pose(at: time).opacity
        if dim > 0.01 { context.fill(LightFX.disc(WelcomeScript.cue, 3.3), with: .color(Palette.aiTextStrong.opacity(dim))) }
    }

    /// A dot: a soft halo, the coloured light and a white-hot centre, bigger and brighter at the hit, then breathing (`shine`) and glinting
    /// now and then, like a star.
    private func drawDot(_ dot: WelcomeDot, index: Int, in context: inout GraphicsContext) {
        let pop = dot.pop.pose(at: time)
        if pop.opacity > 0.01 {
            let shine = WelcomeScript.shine(of: index, lit: dot.hit, at: ambient)
            let flash = dot.flash.pose(at: time).opacity
            let size = dot.radius * pop.scale * (1 + 0.2 * shine)
            let halo = (0.3 + 0.25 * shine + 0.5 * flash) * pop.opacity
            glow(at: dot.point, radius: dot.radius * (3 + 3 * flash + 1.2 * shine), color: dot.color, opacity: halo, in: &context)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: dot.color.opacity(0.8), radius: dot.radius * (0.9 + 0.9 * shine + 1.6 * flash)))
                layer.fill(LightFX.disc(dot.point, size), with: .color(dot.color.opacity(pop.opacity)))
            }
            context.fill(LightFX.disc(dot.point, size * 0.45), with: .color(.white.opacity((0.55 + 0.45 * max(shine, flash)) * pop.opacity)))
            let glint = WelcomeScript.glint(of: index, lit: dot.hit, at: ambient)
            let sparkle = Pose(opacity: glint, scale: 0.5 + 0.5 * glint, rotation: dot.twinkles ? 45 : 0)
            cross(at: dot.point, horizontal: dot.radius * 6, vertical: dot.radius * 6, thickness: 1.2, color: .white, pose: sparkle, in: &context)
        }
        let ring = dot.ring.pose(at: time)
        if ring.opacity > 0.01 {
            context.stroke(LightFX.disc(dot.point, 6 * ring.scale), with: .color(.white.opacity(ring.opacity)), lineWidth: 1.3)
        }
        cross(at: dot.point, horizontal: 44, vertical: 30.8, thickness: 1.8, color: .white, pose: dot.flare.pose(at: time), in: &context)
    }

    private func drawDust(in context: inout GraphicsContext) {
        for dust in WelcomeScript.dust {
            let pose = dust.track.pose(at: time)
            cross(
                at: dust.point, horizontal: dust.size, vertical: dust.size, thickness: 1, color: Palette.Universe.starWarm, pose: pose, glows: false,
                in: &context
            )
        }
    }

    // MARK: - Sparks

    private func drawSparks(in context: inout GraphicsContext) {
        for dot in WelcomeScript.dots { sparks(dot.sparks, from: dot.point, in: &context) }
        for (index, hit) in WelcomeScript.wordHits.enumerated() {
            sparks(WelcomeScript.wordSparks[index], from: wordCentre(hit: hit), in: &context)
        }
        sparks(WelcomeScript.explosionSparks, from: WelcomeScript.cue, in: &context)
    }

    private func sparks(_ sparks: [WelcomeSpark], from centre: CGPoint, in context: inout GraphicsContext) {
        for spark in sparks {
            let pose = spark.track.pose(at: time)
            guard pose.opacity > 0.01 else { continue }
            let radians = spark.angle * .pi / 180
            let point = CGPoint(x: centre.x + cos(radians) * pose.x, y: centre.y + sin(radians) * pose.x)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: spark.color.opacity(0.95), radius: 6))
                layer.fill(LightFX.disc(point, spark.size / 2 * pose.scale), with: .color(spark.color.opacity(pose.opacity)))
            }
        }
    }

    /// Where the star lands on a word: the point of the path at the second it arrives.
    private func wordCentre(hit: Double) -> CGPoint {
        let pose = starPath.pose(at: hit)
        return CGPoint(x: pose.x, y: pose.y)
    }

    // MARK: - The star

    /// The star and its tail (`StarRibbon`), along the path it takes this time.
    private func drawStar(in context: inout GraphicsContext) {
        let trail = StarRibbon.trail(at: time) { second in
            let pose = starPath.pose(at: second)
            return (CGPoint(x: pose.x, y: pose.y), pose.opacity)
        }
        StarRibbon.draw(trail, in: &context)
        if let head = trail.first { StarRibbon.head(at: head.point, opacity: head.opacity, spin: ambient, in: &context) }
    }

    // MARK: - The explosion

    /// The star becomes the sixth dot: the core, its glow, two rings and the cross of yellow light.
    private func drawExplosion(in context: inout GraphicsContext) {
        let centre = WelcomeScript.cue
        let shine = WelcomeScript.shine(of: 5, lit: WelcomeScript.explosionTime + 0.2, at: ambient)
        let core = WelcomeScript.core.pose(at: time).scale * (1 + 0.12 * shine)
        if core > 0.01 {
            glow(at: centre, radius: 26 * core, color: Palette.acc, opacity: 0.18 + 0.2 * shine, in: &context)
            context.fill(LightFX.disc(centre, 16 * core), with: .color(Palette.acc.opacity(0.22)))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.acc.opacity(0.6), radius: 6))
                layer.fill(LightFX.disc(centre, 6.5 * core), with: .color(Palette.acc))
            }
            context.fill(LightFX.disc(centre, 2.6 * core), with: .color(Palette.Universe.starCream))
        }
        let glint = WelcomeScript.glint(of: 5, lit: WelcomeScript.explosionTime + 0.2, at: ambient)
        cross(
            at: centre, horizontal: 40, vertical: 30, thickness: 1.3, color: Palette.Universe.starCream,
            pose: Pose(opacity: glint, scale: 0.5 + 0.5 * glint), in: &context
        )
        let ring = WelcomeScript.ring.pose(at: time)
        if ring.opacity > 0.01 { context.stroke(LightFX.disc(centre, 10 * ring.scale), with: .color(Palette.acc.opacity(ring.opacity)), lineWidth: 1.2) }
        let second = WelcomeScript.secondRing.pose(at: time)
        if second.opacity > 0.01 {
            context.stroke(LightFX.disc(centre, 10 * second.scale), with: .color(Palette.Universe.starCream.opacity(second.opacity)), lineWidth: 1)
        }
        cross(
            at: centre, horizontal: 150, vertical: 105, thickness: 1.8, color: Palette.Universe.starGold, pose: WelcomeScript.flare.pose(at: time),
            in: &context
        )
    }

    // MARK: - Shapes

    /// A soft round light: `color` at `opacity` in the middle, nothing at `radius`.
    private func glow(at centre: CGPoint, radius: CGFloat, color: Color, opacity: Double, in context: inout GraphicsContext) {
        guard opacity > 0.01, radius > 0.1 else { return }
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(0)]), center: centre, startRadius: 0, endRadius: radius
        )
        context.fill(LightFX.disc(centre, radius), with: shading)
    }

    /// A four-point cross of light: two thin bars that fade out at their ends, turned, scaled and faded by `pose`.
    private func cross(
        at centre: CGPoint, horizontal: CGFloat, vertical: CGFloat, thickness: CGFloat, color: Color, pose: Pose, glows: Bool = true,
        in context: inout GraphicsContext
    ) {
        guard pose.opacity > 0.01, pose.scale > 0.01 else { return }
        var layer = context
        layer.opacity = pose.opacity
        layer.translateBy(x: centre.x, y: centre.y)
        layer.rotate(by: .degrees(pose.rotation))
        layer.scaleBy(x: pose.scale, y: pose.scale)
        if glows { layer.addFilter(.shadow(color: color.opacity(0.9), radius: 3)) }
        func fade(_ start: CGPoint, _ end: CGPoint) -> GraphicsContext.Shading {
            .linearGradient(
                Gradient(stops: [
                    .init(color: color.opacity(0), location: 0), .init(color: color.opacity(0.4), location: 0.3), .init(color: color, location: 0.5),
                    .init(color: color.opacity(0.4), location: 0.7), .init(color: color.opacity(0), location: 1),
                ]),
                startPoint: start, endPoint: end
            )
        }
        let bar = CGRect(x: -horizontal / 2, y: -thickness / 2, width: horizontal, height: thickness)
        layer.fill(Path(roundedRect: bar, cornerRadius: thickness / 2), with: fade(CGPoint(x: bar.minX, y: 0), CGPoint(x: bar.maxX, y: 0)))
        let post = CGRect(x: -thickness / 2, y: -vertical / 2, width: thickness, height: vertical)
        layer.fill(Path(roundedRect: post, cornerRadius: thickness / 2), with: fade(CGPoint(x: 0, y: post.minY), CGPoint(x: 0, y: post.maxY)))
    }
}
