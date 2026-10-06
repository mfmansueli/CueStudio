//
//  PoseTrack.swift
//  Cue Studio
//

import SwiftUI

/// A thing's poses over time, as a CSS `@keyframes` has them: before the first keyframe it holds the first pose, after the last the
/// last, and between two it eases with the curve of the earlier one (the track's own when that has none). The boards' motion values
/// translate one to one, and a drawn scene (a `Canvas` in a `TimelineView`) reads the pose at the time it is drawing.
nonisolated struct PoseTrack: Sendable {
    struct Keyframe: Sendable {
        let time: Double
        let pose: Pose
        /// The easing of the stretch that starts here.
        var curve: UnitCurve?
    }

    let keyframes: [Keyframe]
    let defaultCurve: UnitCurve

    init(curve: UnitCurve = .linear, _ keyframes: [Keyframe]) {
        self.keyframes = keyframes.sorted { $0.time < $1.time }
        defaultCurve = curve
    }

    /// The time of the last keyframe.
    var duration: Double { keyframes.last?.time ?? 0 }

    func pose(at time: Double) -> Pose {
        guard let first = keyframes.first, let last = keyframes.last else { return Pose() }
        if time <= first.time { return first.pose }
        if time >= last.time { return last.pose }
        guard let index = keyframes.lastIndex(where: { $0.time <= time }) else { return first.pose }
        let from = keyframes[index]
        let to = keyframes[index + 1]
        let span = to.time - from.time
        guard span > 0 else { return to.pose }
        let progress = (from.curve ?? defaultCurve).value(at: (time - from.time) / span)
        return from.pose.mixed(with: to.pose, progress: progress)
    }
}

nonisolated extension PoseTrack.Keyframe {
    /// A keyframe, written the way the boards write them: the time, then only what that moment changes.
    init(
        _ time: Double, opacity: Double = 1, scale: Double = 1, scaleX: Double = 1, scaleY: Double = 1, rotation: Double = 0,
        x: Double = 0, y: Double = 0, blur: Double = 0, curve: UnitCurve? = nil
    ) {
        self.init(
            time: time, pose: Pose(opacity: opacity, scale: scale, scaleX: scaleX, scaleY: scaleY, rotation: rotation, x: x, y: y, blur: blur),
            curve: curve
        )
    }
}
