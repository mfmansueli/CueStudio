//
//  ScriptsConstellation.swift
//  Cue Studio
//

import SwiftUI

/// The first visit's mark (3.1): a yellow star with a halo that breathes (14 → 19 → 14 pt over 3 s) at the end of a dotted line that
/// joins three small stars, in a 160 × 104 box. Still under Reduce Motion.
struct ScriptsConstellation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            // r: 14 → 19 → 14 on a 3 s cycle (SVG `animate values="14;19;14" dur="3s"`).
            let halo = 14 + 5 * (0.5 - 0.5 * cos(time * 2 * .pi / 3))
            Canvas { canvas, _ in
                var line = Path()
                line.move(to: CGPoint(x: 24, y: 78))
                line.addLine(to: CGPoint(x: 64, y: 44))
                line.addLine(to: CGPoint(x: 104, y: 62))
                line.addLine(to: CGPoint(x: 126, y: 26))
                canvas.stroke(line, with: .color(Palette.aiTextStrong.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                let stars = [(CGPoint(x: 24, y: 78), 2.4, 0.7), (CGPoint(x: 104, y: 62), 2.2, 0.7), (CGPoint(x: 126, y: 26), 2.0, 0.55)]
                for (point, radius, alpha) in stars {
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    canvas.fill(Path(ellipseIn: rect), with: .color(Palette.aiTextStrong.opacity(alpha)))
                }
                let core = CGPoint(x: 64, y: 44)
                let haloRect = CGRect(x: core.x - halo, y: core.y - halo, width: halo * 2, height: halo * 2)
                canvas.fill(Path(ellipseIn: haloRect), with: .color(Palette.acc.opacity(0.16)))
                canvas.fill(Path(ellipseIn: CGRect(x: core.x - 5, y: core.y - 5, width: 10, height: 10)), with: .color(Palette.acc))
                canvas.fill(Path(ellipseIn: CGRect(x: core.x - 2, y: core.y - 2, width: 4, height: 4)), with: .color(Color(hex: 0xFFF6C2)))
            }
            .frame(width: 160, height: 104)
        }
        .accessibilityHidden(true)
    }
}
