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

    /// As `segment` (starting at `start`, edited seconds) shows at edited `time`: with its zoom and its Animation then.
    nonisolated func moment(of segment: EditSegment, startingAt start: TimeInterval, at time: TimeInterval) -> FramePlacement {
        var placement = self
        placement.zoom = segment.zoom.map {
            ZoomWindow(zoom: $0, start: start, duration: segment.duration, amount: segment.zoomAmount).scale(at: time)
        } ?? 1
        if segment.animates {
            let window = ClipAnimationWindow(
                start: start, duration: segment.duration, entrance: segment.animationIn, exit: segment.animationOut
            )
            placement.animation = window.state(at: time) ?? .still
        }
        return placement
    }
}
