//
//  TrackScale.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How a layer track turns edited seconds into points and back: like the Trim strip at its zoom
/// and scroll, so the shared timeline's tracks line up with the frames above them.
struct TrackScale {
    let layout: TimelineLayout

    func x(for time: TimeInterval) -> CGFloat { layout.x(forEdited: time) }

    func time(at x: CGFloat) -> TimeInterval {
        min(max(0, layout.editedTime(atX: x)), layout.timeline.editedDuration)
    }

    /// Seconds a given number of points stands for.
    func seconds(for points: CGFloat) -> TimeInterval {
        layout.pointsPerSecond > 0 ? Double(points / layout.pointsPerSecond) : 0
    }
}
