//
//  ZoomMoment.swift
//  Cue Studio
//

import Foundation

/// The one way a clip's zooms add up at a moment, for the compositor (`CueVideoCompositor`) and the handles over the preview
/// (`FramePlacement.moment`) alike: the clip's zoom (the creator's or Punch in on cuts'), the phrase zooms over it (never past
/// `PhraseZoom.maximumTotal` together), grown around the clip's `ZoomAnchor` within its limits.
nonisolated enum ZoomMoment {
    /// Times the frame and the point it grows around (fractions of the frame, from the top left) at edited `time`.
    static func at(
        _ time: TimeInterval, section: ZoomWindow?, phrases: [PhraseZoomWindow], anchor: ZoomAnchor?
    ) -> (scale: Double, pivot: OverlayPoint) {
        let sectionScale = section?.scale(at: time) ?? 1
        let combined = PhraseZoomWindow.combined(sectionScale, PhraseZoomWindow.scale(of: phrases, at: time))
        guard let anchor else { return (combined, .center) }
        let isManual = section.map { !$0.punchesInOnCut } ?? false
        return anchor.zoom(section: sectionScale, sectionIsManual: isManual, combined: combined)
    }
}
