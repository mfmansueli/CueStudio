//
//  TimelineSnapping.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The playhead and the handles stick to cuts, the edges of captions and texts and keyframes when
/// they come within a few points of one. Pure.
nonisolated enum TimelineSnapping {
    /// How close (points on screen) a time has to come to stick.
    static let distance: CGFloat = 6

    /// The snap time within `distance` points of `time`, if any (the nearest).
    static func snapped(_ time: TimeInterval, to targets: [TimeInterval], pointsPerSecond: CGFloat) -> TimeInterval? {
        let reach = TimeInterval(distance / max(0.001, pointsPerSecond))
        var best: TimeInterval?
        for target in targets where abs(target - time) <= reach {
            if best.map({ abs(target - time) < abs($0 - time) }) ?? true { best = target }
        }
        return best
    }
}
