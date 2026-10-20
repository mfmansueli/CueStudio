//
//  SourceFrame.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How a recording's frames become the edit's frame: its track's transform (portrait recordings
/// upright), the part of the upright frame to keep, and the scale that brings it to the take's
/// frame size (1 for the take itself; another take or video of a montage is scaled to match), and
/// its background effect. With Follow face, the part kept moves over time (`follow`); with Eye Contact, the eyes of each frame are
/// moved first (`eyes`).
nonisolated struct SourceFrame: Sendable {
    let transform: CGAffineTransform
    /// Core Image coordinates.
    let crop: CGRect
    let scale: CGFloat
    var background: BackgroundRender?
    /// Follow face: where the crop's center is over the recording's own seconds; nil keeps `crop` still.
    var follow: FaceFollowPath?
    /// The recording's upright frame, in pixels (for the crop that follows).
    var uprightSize: CGSize = .zero
    /// Stabilize: how each moment of the recording is held steady; nil plays it as filmed.
    var steady: StabilizationPath?
    /// Eye Contact: the eyes moved toward the lens on each frame of the recording it decided for; nil plays it as filmed.
    var eyes: EyeContactTrack?

    init(transform: CGAffineTransform, crop: CGRect, scale: CGFloat, background: BackgroundRender? = nil) {
        self.transform = transform
        self.crop = crop
        self.scale = scale
        self.background = background
    }

    /// The part of the upright frame kept at `time` (seconds of the recording), in Core Image coordinates: `crop`, or the same
    /// size around where Follow face has it then, never outside the frame.
    func cropRect(at time: TimeInterval) -> CGRect {
        guard let follow, uprightSize.width > 0, uprightSize.height > 0 else { return crop }
        let center = follow.center(at: time)
        let left = min(max(0, center.x * uprightSize.width - crop.width / 2), uprightSize.width - crop.width)
        let top = min(max(0, center.y * uprightSize.height - crop.height / 2), uprightSize.height - crop.height)
        return CGRect(x: left, y: uprightSize.height - top - crop.height, width: crop.width, height: crop.height)
    }
}
