//
//  Framing.swift
//  Cue Studio
//

import Foundation

/// How the compositor frames one recording's frame (`CueVideoCompositor`): where it lands on the take's frame (`frame`:
/// crop, scale, Follow face, Stabilize, background), Fill or Fit, its look (the clip's own over the take's), the name of the
/// moment for the person masks kept, the moment for Skin Smoothing, and the moment of the recording it shows (where Follow
/// face has the crop and Stabilize its correction).
nonisolated struct Framing {
    let frame: SourceFrame
    let cropFit: CropFit
    let look: LookSettings
    let key: String
    let moment: SmoothingMoment
    let sourceTime: TimeInterval
}
