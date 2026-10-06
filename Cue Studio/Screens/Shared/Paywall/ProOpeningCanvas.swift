//
//  ProOpeningCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The light of the Pro opening at one second of `ProOpeningScript`: the streaks rushing in, the golden core rising into the planet, the ring of gold
/// and the warm flash.
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
                    Gradient(colors: [Palette.starCream.opacity(0), Palette.starCream.opacity(0.9 * (1 - progress * progress))]),
                    startPoint: tail, endPoint: head
                ),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
    }

    /// The core grows at the focus, then rises into the planet.
    private func drawCore(in canvas: inout GraphicsContext, focus: CGPoint) {
        let core = ProOpeningScript.core.pose(at: time)
        let centre = CGPoint(x: focus.x, y: focus.y + (planetY - focus.y) * core.y)
        if core.opacity > 0.01 {
            let radius = 30 * core.scale
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.acc.opacity(0.8), radius: 18))
                layer.fill(
                    Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Palette.starCream.opacity(core.opacity), Palette.acc.opacity(0.9 * core.opacity), Palette.acc.opacity(0)]),
                        center: centre, startRadius: 0, endRadius: radius
                    )
                )
            }
        }
        let wave = ProOpeningScript.shockwave.pose(at: time)
        if wave.opacity > 0.01 {
            let radius = 12 * wave.scale
            canvas.stroke(
                Path(ellipseIn: CGRect(x: focus.x - radius, y: focus.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Palette.acc.opacity(wave.opacity)), lineWidth: 1.2
            )
        }
    }

    private func drawFlash(in canvas: inout GraphicsContext, size: CGSize, focus: CGPoint) {
        let flash = ProOpeningScript.flash.pose(at: time).opacity
        guard flash > 0.01 else { return }
        canvas.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [Palette.starCream.opacity(flash), Palette.acc.opacity(flash * 0.4), .clear]),
                center: focus, startRadius: 0, endRadius: max(size.width, size.height) * 0.7
            )
        )
    }
}
