//
//  StarCourse.swift
//  Cue Studio
//

import SwiftUI

/// Where the star is: on the curve from the arrow to the middle as `path` goes 0 → 1, then on the line from the middle to the caret as
/// `landed` goes 0 → 1; `fall` pushes it down when it leaves. With Reduce Motion it just sits in the middle.
struct StarCourse: GeometryEffect {
    var path: CGFloat
    var landed: CGFloat
    let from: CGPoint
    let control: CGPoint
    let centre: CGPoint
    let caret: CGPoint
    var fall: CGFloat
    let flies: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(path, landed), fall) }
        set {
            path = newValue.first.first
            landed = newValue.first.second
            fall = newValue.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let spot: CGPoint
        if !flies {
            spot = centre
        } else if landed > 0 {
            spot = CGPoint(x: centre.x + (caret.x - centre.x) * landed, y: centre.y + (caret.y - centre.y) * landed)
        } else {
            let t = path
            let u = 1 - t
            spot = CGPoint(
                x: u * u * from.x + 2 * u * t * control.x + t * t * centre.x,
                y: u * u * from.y + 2 * u * t * control.y + t * t * centre.y
            )
        }
        return ProjectionTransform(CGAffineTransform(translationX: spot.x - size.width / 2, y: spot.y + fall - size.height / 2))
    }
}
