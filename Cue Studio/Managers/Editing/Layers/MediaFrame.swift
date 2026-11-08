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
    /// How a support sits in its area (`MediaOverlay.areaFraming`), or a window's or full-screen picture in its place
    /// (`pictureFraming`, always Fill there).
    var areaFraming = AreaFraming()
    /// The photo or video over the take this draws (`MediaOverlay.id`).
    var mediaID: UUID?
    /// Drawn for the editor's preview, where the picked photo or video shows whole while paused (`PreviewMotionHold`).
    var readsPreviewHold = false
    /// Its pieces with the second of its file each starts at, for the Blur areas on it.
    var filePieces: [MediaPiece] = []
    /// The Blur areas on it (`BlurRegion.target`).
    var blurs: [BlurRegion] = []
    /// Its mask, when it has one and isn't a support.
    var mask: MediaMask?
    /// How opaque it is (`MediaOverlay.opacity`), times what its keyframes say.
    var opacity = 1.0

    /// Shown Behind you (`MediaLayout.behind`): it fills the frame behind the cut-out creator.
    var isBehind = false

    var isSupport: Bool { areas != nil }

    var isVideo: Bool { image == nil }

    func isVisible(at time: TimeInterval) -> Bool {
        guard let pieces else { return span.contains(time) }
        return pieces.contains { $0.contains(time) }
    }

    /// Edited seconds it shows, piece by piece.
    var shownSpans: [TimeSpan] { pieces ?? [span] }

    /// The second of its file shown at `time` (edited seconds).
    func fileTime(at time: TimeInterval) -> TimeInterval {
        guard let piece = filePieces.first(where: { $0.edited.start - 0.000_1 <= time && time <= $0.edited.end + 0.000_1 }) ?? filePieces.first
        else { return 0 }
        return piece.fileStart + max(0, time - piece.edited.start)
    }

    /// `picture` (upright, its corner at the origin) with the Blur areas on it at `time` hidden.
    func hidingBlurs(_ picture: CIImage, at time: TimeInterval) -> CIImage {
        guard !blurs.isEmpty, let mediaID else { return picture }
        return BlurDrawing.apply(BlurResolver.shown(blurs, onMedia: mediaID, at: fileTime(at: time), isPhoto: !isVideo), to: picture)
    }
}
