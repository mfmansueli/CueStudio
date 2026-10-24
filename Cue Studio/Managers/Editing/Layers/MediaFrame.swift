//
//  MediaFrame.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage
import CoreMedia
import Foundation

/// A photo or video over the take, ready for the compositor: when it shows, where, and its
/// picture (a photo's image; a video's frames come from the composition's media track). A support of a split screen also
/// carries the areas: the main video goes to its own, the support fills the other as its framing says.
nonisolated struct MediaFrame: @unchecked Sendable {
    /// Edited seconds it shows, from the start of its first piece to the end of its last.
    let span: TimeSpan
    /// Where it shows without a break (`MediaOverlay.pieces`); the whole span when nil.
    var pieces: [TimeSpan]?
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
    /// A split screen's areas on the frame (from the top left), when it is a support.
    var areas: SplitPlacement.Areas?
    /// How a support sits in its area.
    var areaFraming = AreaFraming()

    var isSupport: Bool { areas != nil }

    var isVideo: Bool { image == nil }

    func isVisible(at time: TimeInterval) -> Bool {
        guard let pieces else { return span.contains(time) }
        return pieces.contains { $0.contains(time) }
    }

    /// Edited seconds it shows, piece by piece.
    var shownSpans: [TimeSpan] { pieces ?? [span] }
}
