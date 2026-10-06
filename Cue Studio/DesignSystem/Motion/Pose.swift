//
//  Pose.swift
//  Cue Studio
//

import CoreGraphics

/// How one thing of a drawn scene looks at one moment: the few properties the boards' keyframes move (opacity, size, turn, place and
/// blur). A `PoseTrack` goes from pose to pose.
nonisolated struct Pose: Equatable, Sendable {
    var opacity = 1.0
    /// Both axes at once; `scaleX` and `scaleY` stretch one of them on top of it.
    var scale = 1.0
    var scaleX = 1.0
    var scaleY = 1.0
    /// Degrees.
    var rotation = 0.0
    var x = 0.0
    var y = 0.0
    var blur = 0.0

    /// The pose between `self` and `other`, `progress` (0...1) of the way.
    func mixed(with other: Pose, progress: Double) -> Pose {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * progress }
        return Pose(
            opacity: mix(opacity, other.opacity), scale: mix(scale, other.scale), scaleX: mix(scaleX, other.scaleX),
            scaleY: mix(scaleY, other.scaleY), rotation: mix(rotation, other.rotation), x: mix(x, other.x), y: mix(y, other.y),
            blur: mix(blur, other.blur)
        )
    }
}
