//
//  PhraseZoomWindow.swift
//  Cue Studio
//

import Foundation

/// A phrase zoom where it plays in the drawing (`PhraseZoom`): edited seconds, the lead-in counted.
nonisolated struct PhraseZoomWindow: Hashable, Sendable {
    let span: TimeSpan
    /// Times the frame's size at its full.
    let scale: Double

    /// Times the frame's size at `time`: eased in and out over `PhraseZoom.ramp` (less when the window is short).
    func scale(at time: TimeInterval) -> Double {
        guard span.contains(time) || time == span.end else { return 1 }
        let ramp = min(PhraseZoom.ramp, span.duration / 2)
        let edge = min(time - span.start, span.end - time)
        let progress = ramp > 0 ? min(max(edge / ramp, 0), 1) : 1
        return 1 + (scale - 1) * KeyframeEasing.smooth.apply(progress)
    }

    /// The edit's phrase zooms where `timeline` plays them, `leadIn` seconds into the drawing.
    static func windows(of zooms: [PhraseZoom], in timeline: EditTimeline, leadIn: TimeInterval = 0) -> [PhraseZoomWindow] {
        zooms.compactMap { zoom in
            timeline.editedSpan(forSource: zoom.span, in: zoom.sourceID).map {
                PhraseZoomWindow(span: TimeSpan(start: $0.start + leadIn, end: $0.end + leadIn), scale: zoom.strength.scale)
            }
        }
    }

    /// The closest any of `windows` is at `time` (they don't add up when two touch).
    static func scale(of windows: [PhraseZoomWindow], at time: TimeInterval) -> Double {
        windows.reduce(1) { max($0, $1.scale(at: time)) }
    }

    /// The clip's zoom `section` and the phrase zoom together, never closer than `PhraseZoom.maximumTotal`.
    static func combined(_ section: Double, _ phrase: Double) -> Double {
        guard phrase > 1 else { return section }
        return min(section * phrase, max(section, PhraseZoom.maximumTotal))
    }
}
