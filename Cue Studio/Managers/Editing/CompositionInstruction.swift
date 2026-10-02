//
//  CompositionInstruction.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// Everything the compositor needs for a stretch of the edited video: which tracks to read, how
/// the recording is rotated, the crop, the look, the transitions and what to lay on top (media,
/// texts, captions).
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let trackID: CMPersistentTrackID
    /// The track with the other side of a dissolving cut; nil outside a dissolve.
    let blendTrackID: CMPersistentTrackID?
    /// The tracks with the videos laid over the take in this stretch (several when they overlap).
    let mediaTrackIDs: [CMPersistentTrackID]
    /// How the main track's frames become the edit's frame in this stretch (upright, cropped,
    /// scaled): a stretch plays one recording.
    let frame: SourceFrame
    /// The same for the blend track's frames (the other side of a dissolve); nil outside one.
    let blendFrame: SourceFrame?
    let edit: TakeEdit
    /// The light, color and filter of the clip this stretch plays: the take's, with that clip's own
    /// overrides on top.
    let look: LookSettings
    /// The same for the other side of a dissolve (its own clip's); nil outside one.
    let blendLook: LookSettings?
    let overlays: [FrameOverlay]
    /// Every photo and video laid over the take.
    let media: [MediaFrame]
    /// Output size over crop size (below 1 when exporting at a lower quality).
    let outputScale: CGFloat
    /// The dissolve this stretch is, if it is one.
    let dissolve: TransitionWindow?
    /// The slow zoom of the section this stretch plays, if it has one.
    let zoom: ZoomWindow?
    /// Every fade in the edit: a frame inside one darkens.
    let fades: [TransitionWindow]

    init(
        timeRange: CMTimeRange, trackID: CMPersistentTrackID, blendTrackID: CMPersistentTrackID? = nil,
        mediaTrackIDs: [CMPersistentTrackID] = [],
        frame: SourceFrame, blendFrame: SourceFrame? = nil, edit: TakeEdit, look: LookSettings? = nil, blendLook: LookSettings? = nil,
        overlays: [FrameOverlay], media: [MediaFrame] = [],
        outputScale: CGFloat, dissolve: TransitionWindow? = nil, zoom: ZoomWindow? = nil, fades: [TransitionWindow] = []
    ) {
        self.zoom = zoom
        self.timeRange = timeRange
        self.trackID = trackID
        self.blendTrackID = blendTrackID
        self.mediaTrackIDs = mediaTrackIDs
        self.media = media
        self.frame = frame
        self.blendFrame = blendFrame
        self.edit = edit
        self.look = look ?? LookSettings(edit)
        self.blendLook = blendLook
        self.overlays = overlays
        self.outputScale = outputScale
        self.dissolve = dissolve
        self.fades = fades
        requiredSourceTrackIDs = ([trackID] + [blendTrackID].compactMap { $0 } + mediaTrackIDs).map { NSNumber(value: $0) }
    }
}
