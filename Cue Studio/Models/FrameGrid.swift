//
//  FrameGrid.swift
//  Cue Studio
//

import Foundation

/// The recording's frames in time: where each one starts, at the file's own rate. Quick edit puts
/// the playhead, the trim handles and the red range on them, so an edit never lands between two
/// frames and a creator can take out exactly a few.
nonisolated struct FrameGrid: Hashable, Sendable {
    /// Frames per second.
    let rate: Double

    /// `rate` from the file; 30 when it can't be read.
    init(rate: Double) {
        self.rate = rate.isFinite && rate >= 1 ? min(rate, 240) : 30
    }

    /// Seconds one frame lasts.
    var frameDuration: TimeInterval { 1 / rate }

    /// The frame of the recording nearest to `time` (seconds of the recording).
    func snapped(_ time: TimeInterval) -> TimeInterval {
        (time * rate).rounded() / rate
    }

    /// The frame nearest to `time` inside `span`, or an end of `span` when that is nearer: the end
    /// of a recording, or a cut, that fell between two frames can still be reached.
    func snapped(_ time: TimeInterval, in span: TimeSpan) -> TimeInterval {
        let onFrame = min(max(snapped(time), span.start), span.end)
        return [onFrame, span.start, span.end].min(by: { abs($0 - time) < abs($1 - time) }) ?? onFrame
    }

    /// The frame nearest to `time` (edited seconds), inside the piece that plays there.
    func snapped(edited time: TimeInterval, in timeline: EditTimeline) -> TimeInterval {
        let index = timeline.segmentIndex(atEdited: time)
        let segment = timeline.segments[index]
        let start = timeline.editedStart(ofSegmentAt: index)
        let source = snapped(segment.sourceStart + (time - start), in: segment.span)
        return min(max(0, start + source - segment.sourceStart), timeline.editedDuration)
    }

    /// Where the frames inside `span` start (seconds of the recording), in order.
    func frameStarts(in span: TimeSpan) -> [TimeInterval] {
        guard span.end > span.start else { return [] }
        let first = Int((span.start * rate - 0.000_1).rounded(.up))
        let last = Int((span.end * rate + 0.000_1).rounded(.down))
        guard last >= first else { return [] }
        return (first...last).map { Double($0) / rate }
    }
}
