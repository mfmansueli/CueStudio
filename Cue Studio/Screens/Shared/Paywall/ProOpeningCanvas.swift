//
//  ProOpeningCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The light of the Pro opening at one second of `ProOpeningScript`: the streaks rushing in, the golden star with its ring of gold and the warm
/// flash, its flight up with the first flight's trail (`StarRibbon`), and the planet's birth: the ring of light gathering, the bloom and the sparks.
struct ProOpeningCanvas: View {
    let time: Double
    /// Where the planet that is you sits, from the top of the screen.
    let planetY: CGFloat

    var body: some View {
        Canvas { canvas, size in
            let focus = CGPoint(x: size.width / 2, y: size.height * 0.44)
            drawFlash(in: &canvas, size: size, focus: focus)
            drawStreaks(in: &canvas, size: size, focus: focus)
            drawCore(in: &canvas, focus: focus)
            drawBirth(in: &canvas, at: CGPoint(x: size.width / 2, y: planetY))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawStreaks(in canvas: inout GraphicsContext, size: CGSize, focus: CGPoint) {
        let reach = hypot(size.width, size.height) / 2 + 40
        for streak in ProOpeningScript.streaks {
            let progress = ProOpeningScript.progress(of: streak, at: time)
            guard progress > 0, progress < 1 else { continue }
            let radians = streak.angle * .pi / 180
            let direction = CGPoint(x: cos(radians), y: sin(radians))
            // The head travels from the edge to the focus; the tail trails behind it, shrinking as it arrives.
            let distance = reach * (1 - progress)
            let head = CGPoint(x: focus.x + direction.x * distance, y: focus.y + direction.y * distance)
            let length = streak.length * (1 - 0.6 * progress)
            let tail = CGPoint(x: head.x + direction.x * length, y: head.y + direction.y * length)
            var path = Path()
            path.move(to: tail)
            path.addLine(to: head)
            canvas.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [Palette.Universe.starCream.opacity(0), Palette.Universe.starCream.opacity(0.9 * (1 - progress * progress))]),
                    startPoint: tail, endPoint: head
                ),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
    }

    /// The star grows at the focus, then flies up to the planet with its trail; its ring of gold opens at the focus.
    private func drawCore(in canvas: inout GraphicsContext, focus: CGPoint) {
        let planet = CGPoint(x: focus.x, y: planetY)
        func head(at second: Double) -> StarRibbon.Point {
            let pose = ProOpeningScript.core.pose(at: second)
            let flying = second >= 1.5 ? pose.opacity : 0
            return (ProOpeningScript.flight(from: focus, to: planet, progress: pose.y), flying)
        }
        StarRibbon.draw(
            StarRibbon.trail(at: time, length: 0.36, head: head),
            colors: [.white, Palette.Universe.starCream, Palette.acc, Palette.Universe.starGold], width: 5, in: &canvas
        )
        let core = ProOpeningScript.core.pose(at: time)
        if core.opacity > 0.01 {
            let centre = ProOpeningScript.flight(from: focus, to: planet, progress: core.y)
            // A soft gold light round a small white-hot heart, and the star's cross turning: a star, not a blob.
            let glow = 34 * core.scale
            canvas.fill(
                disc(centre, glow),
                with: .radialGradient(
                    Gradient(colors: [Palette.acc.opacity(0.75 * core.opacity), Palette.acc.opacity(0.22 * core.opacity), Palette.acc.opacity(0)]),
                    center: centre, startRadius: 0, endRadius: glow
                )
            )
            StarRibbon.head(at: centre, opacity: core.opacity, spin: time, radius: 6 * core.scale, halo: Palette.acc, in: &canvas)
        }
        let wave = ProOpeningScript.shockwave.pose(at: time)
        if wave.opacity > 0.01 {
            canvas.stroke(disc(focus, 12 * wave.scale), with: .color(Palette.acc.opacity(wave.opacity)), lineWidth: 1.2)
        }
    }

    /// Where the star arrives: a ring of light closes in, and the planet is born in a bloom of light that throws out sparks.
    private func drawBirth(in canvas: inout GraphicsContext, at centre: CGPoint) {
        let radius = ProPlanetArt.planetRadius
        let gather = ProOpeningScript.gather.pose(at: time)
        if gather.opacity > 0.01 {
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.acc.opacity(0.9 * gather.opacity), radius: 8))
                layer.stroke(disc(centre, radius * gather.scale), with: .color(Palette.Universe.starCream.opacity(gather.opacity)), lineWidth: 1.6)
            }
        }
        let bloom = ProOpeningScript.birthBloom.pose(at: time)
        if bloom.opacity > 0.01 {
            let reach = 120 * bloom.scale
            canvas.fill(
                disc(centre, reach),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(bloom.opacity), Palette.acc.opacity(0.45 * bloom.opacity), Palette.acc.opacity(0)]),
                    center: centre, startRadius: 0, endRadius: reach
                )
            )
        }
        let sparks = ProOpeningScript.birthSparks.pose(at: time)
        guard sparks.opacity > 0.01 else { return }
        for index in 0..<ProOpeningScript.sparkCount {
            let angle = Double(index) / Double(ProOpeningScript.sparkCount) * 2 * .pi + 0.3
            let reach = (radius + 18 + Double((index * 37) % 50)) * sparks.scale + radius * (1 - sparks.scale)
            let point = CGPoint(x: centre.x + cos(angle) * reach, y: centre.y + sin(angle) * reach * 0.8)
            let color = index.isMultiple(of: 3) ? Color.white : Palette.Universe.starGold
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(sparks.opacity), radius: 4))
                layer.fill(disc(point, 1.8 * (1 - 0.6 * sparks.scale) + 0.4), with: .color(color.opacity(sparks.opacity)))
            }
        }
    }

    private func disc(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }

    private func drawFlash(in canvas: inout GraphicsContext, size: CGSize, focus: CGPoint) {
        let flash = ProOpeningScript.flash.pose(at: time).opacity
        guard flash > 0.01 else { return }
        canvas.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [Palette.Universe.starCream.opacity(flash), Palette.acc.opacity(flash * 0.4), .clear]),
                center: focus, startRadius: 0, endRadius: max(size.width, size.height) * 0.7
            )
        )
    }
}
