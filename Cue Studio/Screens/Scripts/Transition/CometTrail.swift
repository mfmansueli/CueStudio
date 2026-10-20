//
//  CometTrail.swift
//  Cue Studio
//

import SwiftUI

/// The light the star leaves behind as it flies from the middle to the caret (`StarCourse`'s line, as `landed` goes 0 → 1): a streak that
/// grows behind it and shrinks to nothing as it lands. Drawn in the overlay's coordinates; stroked by the caller.
nonisolated struct CometTrail: Shape {
    var landed: CGFloat
    let centre: CGPoint
    let caret: CGPoint

    var animatableData: CGFloat {
        get { landed }
        set { landed = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard landed > 0, landed < 1 else { return path }
        // Longest mid-flight, nothing at either end.
        let tail = max(0, landed - 0.45 * sin(.pi * landed))
        path.move(to: point(at: tail))
        path.addLine(to: point(at: landed))
        return path
    }

    private func point(at progress: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + (caret.x - centre.x) * progress, y: centre.y + (caret.y - centre.y) * progress)
    }
}
