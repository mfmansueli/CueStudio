//
//  InspirationOrbit.swift
//  Cue Studio
//

import SwiftUI

/// The small orbital motif of Find inspiration: a tilted violet orbit, a faint inner one and the yellow star of the app on it, as the
/// Scripts constellation and the universe draw them. Still (a moving one would keep drawing behind a card that is being read) and
/// decorative.
struct InspirationOrbit: View {
    var body: some View {
        Canvas { canvas, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            canvas.translateBy(x: center.x, y: center.y)
            canvas.rotate(by: .degrees(-14))
            let outer = CGRect(x: -size.width / 2 + 2, y: -size.height * 0.26, width: size.width - 4, height: size.height * 0.52)
            canvas.stroke(Path(ellipseIn: outer), with: .color(Palette.Scripts.inspirationOrbit), lineWidth: 1)
            let inner = outer.insetBy(dx: outer.width * 0.22, dy: outer.height * 0.22)
            canvas.stroke(
                Path(ellipseIn: inner), with: .color(Palette.Scripts.inspirationOrbit), style: StrokeStyle(lineWidth: 0.8, dash: [2, 4])
            )
            // The core, violet, and the yellow star on the outer orbit.
            canvas.fill(Path(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6)), with: .color(Palette.Scripts.tipGlyph.opacity(0.8)))
            let star = CGPoint(x: outer.maxX * 0.72, y: -outer.height * 0.35)
            canvas.fill(Path(ellipseIn: CGRect(x: star.x - 7, y: star.y - 7, width: 14, height: 14)), with: .color(Palette.acc.opacity(0.18)))
            canvas.fill(Path(ellipseIn: CGRect(x: star.x - 3, y: star.y - 3, width: 6, height: 6)), with: .color(Palette.acc))
            let far = CGPoint(x: -outer.maxX * 0.8, y: outer.height * 0.28)
            canvas.fill(Path(ellipseIn: CGRect(x: far.x - 1.6, y: far.y - 1.6, width: 3.2, height: 3.2)), with: .color(Palette.aiTextStrong.opacity(0.6)))
        }
        .frame(width: 96, height: 44)
        .accessibilityHidden(true)
    }
}
