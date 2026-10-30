//
//  ProOpeningCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The light of the Pro opening at one second of `ProOpeningScript`: the streaks rushing in (two in three gold, the others Ultra AI's lilac), the
/// golden star with its ring of gold and the warm flash, its flight up with the first flight's trail (`StarRibbon`) and the soft bloom where it
/// arrives and becomes the galaxy's core (`ProGalaxyArt` draws the rest).
struct ProOpeningCanvas: View {
    let time: Double
    /// Where the galaxy's core sits, from the top of the screen.
    let coreY: CGFloat

    var body: some View {
        Canvas { canvas, size in
            let focus = CGPoint(x: size.width / 2, y: size.height * 0.44)
            drawFlash(in: &canvas, size: size, focus: focus)
            drawStreaks(in: &canvas, size: size, focus: focus)
            drawCore(in: &canvas, focus: focus)
            drawArrival(in: &canvas, at: CGPoint(x: size.width / 2, y: coreY))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawStreaks(in canvas: inout GraphicsContext, size: CGSize, focus: CGPoint) {
        let reach = hypot(size.width, size.height) / 2 + 40
        for (index, streak) in ProOpeningScript.streaks.enumerated() {
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
            let colour = index.isMultiple(of: 3) ? Palette.aiTextStrong : Palette.Universe.starCream
            canvas.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [colour.opacity(0), colour.opacity(0.9 * (1 - progress * progress))]),
                    startPoint: tail, endPoint: head
                ),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
    }

    /// The star grows at the focus, then flies up to the galaxy's core with its trail; its ring of gold opens at the focus.
    private func drawCore(in canvas: inout GraphicsContext, focus: CGPoint) {
        let target = CGPoint(x: focus.x, y: coreY)
        func head(at second: Double) -> StarRibbon.Point {
            let pose = ProOpeningScript.core.pose(at: second)
            let flying = second >= 1.5 ? pose.opacity : 0
            return (ProOpeningScript.flight(from: focus, to: target, progress: pose.y), flying)
        }
        StarRibbon.draw(
            StarRibbon.trail(at: time, length: 0.36, head: head),
            colors: [.white, Palette.Universe.starCream, Palette.acc, Palette.Universe.starGold], width: 5, in: &canvas
        )
        let core = ProOpeningScript.core.pose(at: time)
        if core.opacity > 0.01 {
            let centre = ProOpeningScript.flight(from: focus, to: target, progress: core.y)
            // A soft gold light round a small white-hot heart, and the star's cross turning: a star, not a blob.
            let glow = 34 * core.scale
            canvas.fill(
                LightFX.disc(centre, glow),
                with: .radialGradient(
                    Gradient(colors: [Palette.acc.opacity(0.75 * core.opacity), Palette.acc.opacity(0.22 * core.opacity), Palette.acc.opacity(0)]),
                    center: centre, startRadius: 0, endRadius: glow
                )
            )
            StarRibbon.head(at: centre, opacity: core.opacity, spin: time, radius: 6 * core.scale, halo: Palette.acc, in: &canvas)
        }
        let wave = ProOpeningScript.shockwave.pose(at: time)
        if wave.opacity > 0.01 {
            canvas.stroke(LightFX.disc(focus, 12 * wave.scale), with: .color(Palette.acc.opacity(wave.opacity)), lineWidth: 1.2)
        }
    }

    /// Where the star arrives: a soft white and gold bloom as it becomes the core.
    private func drawArrival(in canvas: inout GraphicsContext, at centre: CGPoint) {
        let bloom = ProOpeningScript.arrival.pose(at: time)
        guard bloom.opacity > 0.01 else { return }
        let reach = 70 * bloom.scale
        canvas.fill(
            LightFX.disc(centre, reach),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(bloom.opacity), Palette.acc.opacity(0.45 * bloom.opacity), Palette.acc.opacity(0)]),
                center: centre, startRadius: 0, endRadius: reach
            )
        )
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
