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
    /// The recording the main track plays in this stretch (nil: the take), whose Blur areas it draws.
    let recordingID: UUID?
    /// The recording of the other side of a dissolve.
    let blendRecordingID: UUID?
    /// How the recording this stretch plays sits in the main area while a support shows (`SplitScreen.framing(for:)`).
    let mainFraming: AreaFraming
    /// The same for the other side of a dissolve; nil outside one.
    let blendMainFraming: AreaFraming?
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
    /// Where the edit starts in the composition (the preview's lead-in): what the look draws over time counts from here.
    let timeOrigin: TimeInterval

    init(
        timeRange: CMTimeRange, trackID: CMPersistentTrackID, blendTrackID: CMPersistentTrackID? = nil,
        mediaTrackIDs: [CMPersistentTrackID] = [],
        frame: SourceFrame, blendFrame: SourceFrame? = nil, recordingID: UUID? = nil, blendRecordingID: UUID? = nil,
        mainFraming: AreaFraming = AreaFraming(), blendMainFraming: AreaFraming? = nil,
        edit: TakeEdit, look: LookSettings? = nil, blendLook: LookSettings? = nil,
        overlays: [FrameOverlay], media: [MediaFrame] = [],
        outputScale: CGFloat, dissolve: TransitionWindow? = nil, zoom: ZoomWindow? = nil, fades: [TransitionWindow] = [],
        timeOrigin: TimeInterval = 0
    ) {
        self.zoom = zoom
        self.timeOrigin = timeOrigin
        self.timeRange = timeRange
        self.trackID = trackID
        self.blendTrackID = blendTrackID
        self.mediaTrackIDs = mediaTrackIDs
        self.media = media
        self.frame = frame
        self.blendFrame = blendFrame
        self.recordingID = recordingID
        self.blendRecordingID = blendRecordingID
        self.mainFraming = mainFraming
        self.blendMainFraming = blendMainFraming
        self.edit = edit
        self.look = look ?? LookSettings(edit)
        self.blendLook = blendLook
        self.overlays = overlays
        self.outputScale = outputScale
        self.dissolve = dissolve
        self.fades = fades
        requiredSourceTrackIDs = ([trackID] + [blendTrackID].compactMap { $0 } + mediaTrackIDs).map { NSNumber(value: $0) }
    }

    /// The moment of its recording the main track shows at `time` (composition seconds): where Follow face and
    /// stabilization read the recording's analysis.
    func sourceTime(at time: TimeInterval) -> TimeInterval {
        edit.timeline.sourceTime(forEdited: time)
    }

    /// The Blur areas on the main track's frame at `time` (composition seconds).
    func blurs(at time: TimeInterval) -> [BlurShown] {
        guard !edit.blurRegions.isEmpty else { return [] }
        return BlurResolver.shown(edit.blurRegions, onRecording: recordingID, at: sourceTime(at: time), sources: edit.sources)
    }

    /// The Blur areas on the other side of a transition at `time`, which shows its recording's second `sourceTime`: frames
    /// from just past its clip's ends, which an area on that clip covers too (as far as a transition reaches).
    func blendBlurs(atSource sourceTime: TimeInterval) -> [BlurShown] {
        guard !edit.blurRegions.isEmpty else { return [] }
        return BlurResolver.shown(
            edit.blurRegions, onRecording: blendRecordingID, at: sourceTime, sources: edit.sources, reach: Self.transitionReach
        )
    }

    /// The longest a transition reads past its clips' ends.
    static let transitionReach: TimeInterval = 2
}
