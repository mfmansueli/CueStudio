//
//  SpeedCurveGlyph.swift
//  Cue Studio
//

import SwiftUI

/// A speed curve drawn small: speed up the way (on a logarithmic scale, 1× in the middle), the clip from left to right.
struct SpeedCurveGlyph: View {
    let curve: SpeedCurve
    var color: Color = Palette.ink

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for step in 0...40 {
                let position = Double(step) / 40
                let point = CGPoint(x: size.width * position, y: SpeedCurveEditor.y(forSpeed: curve.speed(at: position), height: size.height))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
