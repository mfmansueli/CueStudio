//
//  Framing.swift
//  Cue Studio
//

import CoreGraphics
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
    /// While a support shows: the main area's size (pixels of the take's frame) and how the recording sits in it. The frame is
    /// then drawn into the area from the whole recording, not from the take's crop.
    var area: (size: CGSize, framing: AreaFraming)?
    /// The Blur areas on this frame of the recording (`BlurResolver`), hidden before anything else moves the picture.
    var blurs: [BlurShown] = []

    init(
        frame: SourceFrame, cropFit: CropFit, look: LookSettings, key: String, moment: SmoothingMoment, sourceTime: TimeInterval,
        lookTime: TimeInterval? = nil, area: (size: CGSize, framing: AreaFraming)? = nil, blurs: [BlurShown] = []
    ) {
        self.area = area
        self.blurs = blurs
        self.frame = frame
        self.cropFit = cropFit
        self.look = look
        self.key = key
        self.moment = moment
        self.sourceTime = sourceTime
        self.lookTime = lookTime ?? moment.time
    }
}
