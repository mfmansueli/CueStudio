//
//  RiseTrail.swift
//  Cue Studio
//

import SwiftUI

/// The light the star leaves behind as it rises from the arrow: the stretch of `StarCourse`'s curve between where the star is (`head`) and
/// where it was a moment ago (`tail`, the same flight a beat later), so it is long while the star is fast and shrinks to nothing as it
/// settles. Drawn in the overlay's coordinates; stroked by the caller.
nonisolated struct RiseTrail: Shape {
    var head: CGFloat
    var tail: CGFloat
    let from: CGPoint
    let control: CGPoint
    let centre: CGPoint

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(head, tail) }
        set {
            head = newValue.first
            tail = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var trail = Path()
        let start = min(tail, head)
        guard head > 0, head - start > 0.002 else { return trail }
        let steps = 14
        trail.move(to: point(at: start))
        for step in 1...steps {
            trail.addLine(to: point(at: start + (head - start) * CGFloat(step) / CGFloat(steps)))
        }
        return trail
    }

    private func point(at t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * from.x + 2 * u * t * control.x + t * t * centre.x,
            y: u * u * from.y + 2 * u * t * control.y + t * t * centre.y
        )
    }
}
