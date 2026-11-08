//
//  CaptionStretchRoom.swift
//  Cue Studio
//

import Foundation

/// How far a caption line's ends go when it is stretched on the timeline (owner, 08/11/2026): each end to the first limit it
/// meets, the next (or previous) line or the cut of the clip it shows in, never over them. The neighbor keeps its time and the
/// words keep their sync; at the limit the handle says which one stopped it.
struct CaptionStretchRoom: Equatable {
    enum Limit: Equatable {
        /// The line next to it.
        case line
        /// The cut between its clip and the next (or previous) one.
        case cut
        /// The start or end of the video: nothing to explain.
        case edge
    }

    var start: TimeInterval
    var startLimit: Limit
    var end: TimeInterval
    var endLimit: Limit

    /// `span`, the line where it plays (edited seconds); `previousEnd` and `nextStart`, its neighbors' ends next to it.
    init(span: TimeSpan, previousEnd: TimeInterval?, nextStart: TimeInterval?, timeline: EditTimeline) {
        let duration = timeline.editedDuration
        let first = timeline.segmentIndex(atEdited: span.start)
        let last = timeline.segmentIndex(atEdited: max(span.start, span.end - 0.000_1))
        let clipStart = timeline.editedStart(ofSegmentAt: first)
        let clipEnd = timeline.editedStart(ofSegmentAt: last) + timeline.segments[last].duration
        if let previousEnd, previousEnd >= clipStart - 0.000_1 {
            (start, startLimit) = (previousEnd, .line)
        } else {
            (start, startLimit) = (clipStart, clipStart > 0.000_1 ? .cut : .edge)
        }
        if let nextStart, nextStart <= clipEnd + 0.000_1 {
            (end, endLimit) = (nextStart, .line)
        } else {
            (end, endLimit) = (clipEnd, clipEnd < duration - 0.000_1 ? .cut : .edge)
        }
        end = max(end, start)
    }

    var span: TimeSpan { TimeSpan(start: start, end: end) }

    /// Whether a handle asked for `time` is held by its limit.
    func holds(_ edge: LayerEdge, at time: TimeInterval) -> Bool {
        edge == .start ? time <= start + 0.000_1 : time >= end - 0.000_1
    }

    /// What the handle says at its limit; nil at the video's own start or end.
    func hint(for edge: LayerEdge) -> String? {
        switch (edge, edge == .start ? startLimit : endLimit) {
        case (.start, .line): String(localized: "Stops at the line before", comment: "Caption handle held by the previous line")
        case (.end, .line): String(localized: "Stops at the next line", comment: "Caption handle held by the next line")
        case (_, .cut): String(localized: "Stops at the cut", comment: "Caption handle held by the clip's cut")
        case (_, .edge): nil
        }
    }
}
