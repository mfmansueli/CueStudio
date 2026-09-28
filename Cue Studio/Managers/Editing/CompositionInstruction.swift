//
//  CompositionInstruction.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// Everything the compositor needs for a stretch of the edited video: which tracks to read, how
/// the recording is rotated, the crop, the look, the transitions and what to lay on top.
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let trackID: CMPersistentTrackID
    /// The track with the other side of a dissolving cut; nil outside a dissolve.
    let blendTrackID: CMPersistentTrackID?
    /// The track's preferred transform, to turn portrait recordings upright.
    let transform: CGAffineTransform
    /// The part of the upright frame to keep (Core Image coordinates).
    let crop: CGRect
    let edit: TakeEdit
    let overlays: [FrameOverlay]
    /// Output size over crop size (below 1 when exporting at a lower quality).
    let outputScale: CGFloat
    /// The dissolve this stretch is, if it is one.
    let dissolve: TransitionWindow?
    /// Every fade in the edit: a frame inside one darkens.
    let fades: [TransitionWindow]

    init(
        timeRange: CMTimeRange, trackID: CMPersistentTrackID, blendTrackID: CMPersistentTrackID? = nil,
        transform: CGAffineTransform, crop: CGRect, edit: TakeEdit, overlays: [FrameOverlay], outputScale: CGFloat,
        dissolve: TransitionWindow? = nil, fades: [TransitionWindow] = []
    ) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.blendTrackID = blendTrackID
        self.transform = transform
        self.crop = crop
        self.edit = edit
        self.overlays = overlays
        self.outputScale = outputScale
        self.dissolve = dissolve
        self.fades = fades
        requiredSourceTrackIDs = ([trackID] + (blendTrackID.map { [$0] } ?? [])).map { NSNumber(value: $0) }
    }
}
