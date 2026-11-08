//
//  QuickEditViewModel+ZoomLimit.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What holds back the zooms Cue makes (`ZoomAnchor`), said where they are chosen: Zoom › Punch in on cuts and Captions › Select ›
/// Zoom (plan §11, §19: a horizontal video cropped to 9:16 is already at about 606 pixels across). Read from the clips' recordings
/// whose size is known (the take's when the editor opens, another recording's once it is analyzed).
extension QuickEditViewModel {
    /// "Zoom stops at 1.12× · the video has too few pixels for more", for Punch in on cuts at its strength.
    var cutZoomLimitNote: String? {
        guard let zoom = edit.cutZoom else { return nil }
        return zoomLimitNote(on: edit.punchedTimeline.segments.filter(\.punchesInOnCut), asking: zoom.strength.scale)
    }

    /// The same for the zoom on the picked caption lines.
    var phraseZoomLimitNote: String? {
        guard let strength = captions.pickedPhraseZoom else { return nil }
        let timeline = edit.punchedTimeline
        let spans = captions.pickedCaptionLines.compactMap { captions.editedSpan(ofCaption: $0.id) }
        let segments = timeline.segments.indices.filter { index in
            let start = timeline.editedStart(ofSegmentAt: index)
            let clip = TimeSpan(start: start, end: start + timeline.segments[index].duration)
            return spans.contains { $0.overlaps(clip) }
        }.map { timeline.segments[$0] }
        return zoomLimitNote(on: segments, asking: strength.scale)
    }

    /// The line when some of `segments` can't go as close as `asked`: the closest they can, and why.
    private func zoomLimitNote(on segments: [EditSegment], asking asked: Double) -> String? {
        let anchors = segments.compactMap(zoomAnchor(of:))
        guard let tightest = anchors.min(by: { $0.limit < $1.limit }), tightest.limit < asked - 0.005 else { return nil }
        let reached = SpeedScale.label(forMultiple: (tightest.limit * 100).rounded(.down) / 100)
        return tightest.resolutionLimit <= tightest.headLimit(around: tightest.pivot)
            ? String(localized: "Zoom stops at \(reached) · the video has too few pixels for more")
            : String(localized: "Zoom stops at \(reached) · so your head stays in the frame")
    }

    /// How Cue's zooms grow on `segment`, as the compositor has it; nil while its recording's size isn't known.
    private func zoomAnchor(of segment: EditSegment) -> ZoomAnchor? {
        let url: URL
        let size: CGSize?
        if let id = segment.sourceID {
            guard let source = edit.sources.first(where: { $0.id == id }) else { return nil }
            url = EditMediaFiles.url(for: source.fileName)
            size = MotionAnalysisStore.complete(forRecording: url).map { CGSize(width: $0.width, height: $0.height) }
        } else {
            url = videoURL
            size = look.recordingUprightSize
        }
        guard let size, size.width > 0, size.height > 0 else { return nil }
        return FramePlacement.recording(url, size: size, in: edit, steadiedBy: segment.stabilization, orientation: segment.orientation)
            .anchored(for: segment, recording: url, in: edit).zoomAnchor
    }
}
