//
//  GridOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Rule-of-thirds grid over the recorded frame.
struct GridOverlay: View {
    /// The recorded frame, in screen points.
    let frame: CGRect

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                let x = frame.minX + frame.width * fraction
                let y = frame.minY + frame.height * fraction
                path.move(to: CGPoint(x: x, y: frame.minY))
                path.addLine(to: CGPoint(x: x, y: frame.maxY))
                path.move(to: CGPoint(x: frame.minX, y: y))
                path.addLine(to: CGPoint(x: frame.maxX, y: y))
            }
            context.stroke(path, with: .color(Palette.Camera.gridLine), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
