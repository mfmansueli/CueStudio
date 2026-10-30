//
//  SparkShape.swift
//  Cue Studio
//

import SwiftUI

/// Ultra AI's ✦ as a shape: four long points on the axes, its waist `waist` of them, filling the rect. The star of an Ultra AI script's
/// transition (`StarTransitionOverlay`) and the sparks round the writer chip (`UltraChipSparks`).
struct SparkShape: Shape {
    var waist: CGFloat = 0.28

    nonisolated func path(in rect: CGRect) -> Path {
        Self.path(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2, waist: waist)
    }

    /// The ✦ round `center`, `radius` to its points, turned by `turn` (a quarter turn ends where it started).
    nonisolated static func path(center: CGPoint, radius: CGFloat, waist: CGFloat = 0.28, turn: Angle = .zero) -> Path {
        var path = Path()
        for index in 0..<8 {
            let angle = turn.radians + Double(index) * .pi / 4 - .pi / 2
            let reach = index.isMultiple(of: 2) ? radius : radius * waist
            let point = CGPoint(x: center.x + reach * cos(angle), y: center.y + reach * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
