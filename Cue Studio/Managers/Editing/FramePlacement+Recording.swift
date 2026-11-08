//
//  FramePlacement+Recording.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

extension FramePlacement {
    /// How the recording at `url` (upright `size`) lands on `edit`'s frame as a clip plays it, as the compositor draws it
    /// (`EditFraming`): reshaped as `orientation` says, Format's crop of that or Fit, Follow face's path and Stabilize's at
    /// `level`; without the moment's zoom or split screen. Reads the recording's analysis.
    nonisolated static func recording(
        _ url: URL, size: CGSize, in edit: TakeEdit, steadiedBy level: StabilizationLevel?, orientation: ClipOrientation
    ) -> FramePlacement {
        let shown = orientation.size(of: size)
        let crop = CropMath.crop(in: shown, aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset)
        var placement = FramePlacement(uprightSize: size, crop: crop, orientation: orientation, fits: edit.cropFit == .fit)
        placement.steady = level.flatMap { MotionAnalysisStore.stabilizationPath(forRecording: url, level: $0) }
        if edit.faceFollow != nil, edit.cropFit == .fill {
            let coreImageCrop = CGRect(x: crop.minX, y: shown.height - crop.maxY, width: crop.width, height: crop.height)
            let analysis = MotionAnalysisStore.complete(forRecording: url).map { orientation.isIdentity ? $0 : $0.oriented(by: orientation) }
            placement.follow = EditedComposition.followPath(for: edit, analysis: analysis, crop: coreImageCrop, size: shown)
        }
        return placement
    }

    /// This placement of `segment`'s recording (at `url`) with how the zooms Cue makes grow on the clip (`ZoomAnchor`), from the
    /// recording's face, as the compositor has it (`EditFraming.zoomAnchor(of:)`).
    nonisolated func anchored(for segment: EditSegment, recording url: URL, in edit: TakeEdit) -> FramePlacement {
        var placement = self
        placement.zoomAnchor = ZoomAnchor.make(
            placement: self, face: MotionAnalysisStore.faceFocus(forRecording: url),
            followsFace: edit.faceFollow != nil && edit.cropFit == .fill, at: (segment.sourceStart + segment.sourceEnd) / 2
        )
        return placement
    }

    /// As `segment` (starting at `start`, edited seconds) shows at edited `time`: with its zoom, the phrase zooms (`phrases`, on
    /// the same edit) around its `zoomAnchor`, and its Animation then. `segment` is of the timeline as drawn
    /// (`TakeEdit.drawnTimeline`), Punch in on cuts written on it.
    nonisolated func moment(
        of segment: EditSegment, startingAt start: TimeInterval, at time: TimeInterval, phrases: [PhraseZoomWindow] = []
    ) -> FramePlacement {
        var placement = self
        let section = segment.zoom.map {
            ZoomWindow(
                zoom: $0, start: start, duration: segment.duration, amount: segment.zoomAmount, punchesInOnCut: segment.punchesInOnCut
            )
        }
        let zoom = ZoomMoment.at(time, section: section, phrases: phrases, anchor: zoomAnchor)
        placement.zoom = zoom.scale
        placement.zoomPivot = zoom.pivot
        if segment.animates {
            let window = ClipAnimationWindow(
                start: start, duration: segment.duration, entrance: segment.animationIn, exit: segment.animationOut
            )
            placement.animation = window.state(at: time) ?? .still
        }
        return placement
    }
}
