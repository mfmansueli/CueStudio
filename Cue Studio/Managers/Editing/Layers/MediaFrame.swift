//
//  MediaFrame.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage
import CoreMedia
import Foundation

/// A photo or video over the take, ready for the compositor: when it shows, where, and its
/// picture (a photo's image; a video's frames come from the composition's media track).
nonisolated struct MediaFrame: @unchecked Sendable {
    /// Edited seconds it shows.
    let span: TimeSpan
    /// Its place on the output frame before scaling (Core Image coordinates: origin at the bottom
    /// left).
    let rect: CGRect
    /// A photo's picture; nil for a video.
    let image: CIImage?
    /// A video's preferred transform, to turn its frames upright.
    let transform: CGAffineTransform
    /// The composition track a video's frames come from; nil for a photo.
    var trackID: CMPersistentTrackID?
    /// Where it stacks: higher is drawn over lower.
    var layer: Int = 0
    /// Keyframed motion over its own time, on a frame of `frameSize`.
    var motion: OverlayMotion?
    var frameSize: CGSize = .zero

    var isVideo: Bool { image == nil }

    func isVisible(at time: TimeInterval) -> Bool {
        span.contains(time)
    }
}
