//
//  Framing.swift
//  Cue Studio
//

import Foundation

/// How the compositor frames one recording's frame (`CueVideoCompositor`): where it lands on the take's frame (`frame`:
/// crop, scale, Follow face, Stabilize, background), Fill or Fit, its look (the clip's own over the take's), the name of the
/// moment for the person masks kept, the moment for Skin Smoothing, and the moment of the recording it shows (where Follow
/// face has the crop and Stabilize its correction). `FramePipeline.framed` draws it.
nonisolated struct Framing {
    let frame: SourceFrame
    let cropFit: CropFit
    let look: LookSettings
    let key: String
    let moment: SmoothingMoment
    let sourceTime: TimeInterval
    /// The edit's own seconds, for what the look draws over time (film grain): the moment's, unless the video starts before
    /// the edit does (the editor's preview, `EditedComposition.Options.shownTimeline`).
    let lookTime: TimeInterval

    init(
        frame: SourceFrame, cropFit: CropFit, look: LookSettings, key: String, moment: SmoothingMoment, sourceTime: TimeInterval,
        lookTime: TimeInterval? = nil
    ) {
        self.frame = frame
        self.cropFit = cropFit
        self.look = look
        self.key = key
        self.moment = moment
        self.sourceTime = sourceTime
        self.lookTime = lookTime ?? moment.time
    }
}
