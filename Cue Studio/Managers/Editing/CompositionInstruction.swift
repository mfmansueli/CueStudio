//
//  CompositionInstruction.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// Everything the compositor needs for a stretch of the edited video: which track to read, how the
/// recording is rotated, the crop, the look and what to lay on top.
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let trackID: CMPersistentTrackID
    /// The track's preferred transform, to turn portrait recordings upright.
    let transform: CGAffineTransform
    /// The part of the upright frame to keep (Core Image coordinates).
    let crop: CGRect
    let edit: TakeEdit
    let overlays: [FrameOverlay]
    /// Output size over crop size (below 1 when exporting at a lower quality).
    let outputScale: CGFloat

    init(
        timeRange: CMTimeRange, trackID: CMPersistentTrackID, transform: CGAffineTransform, crop: CGRect,
        edit: TakeEdit, overlays: [FrameOverlay], outputScale: CGFloat
    ) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.transform = transform
        self.crop = crop
        self.edit = edit
        self.overlays = overlays
        self.outputScale = outputScale
        requiredSourceTrackIDs = [NSNumber(value: trackID)]
    }
}
