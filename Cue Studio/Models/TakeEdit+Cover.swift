//
//  TakeEdit+Cover.swift
//  Cue Studio
//

import Foundation

/// Where the cover's frame is in the edit: picked from the clip under a moment of the edit, found again after the edit changes,
/// and whether it still plays at all.
nonisolated extension TakeEdit {
    /// The frame shown at `time` (edited seconds): the clip playing there, its recording and the second of it.
    func coverFrame(atEdited time: TimeInterval) -> CoverFrame {
        let index = timeline.segmentIndex(atEdited: min(max(0, time), editedDuration))
        let segment = timeline.segments[index]
        return CoverFrame(sourceID: segment.sourceID, segmentID: segment.id, time: timeline.sourceTime(forEdited: time))
    }

    /// The clip that shows `frame` now: the one it was picked on while it still holds that second, else the first clip of the
    /// same recording that does (after a split, a trim or a Clean Up cut). Nil when nothing of the edit shows it.
    func clip(showing frame: CoverFrame) -> (index: Int, segment: EditSegment)? {
        let segments = timeline.segments
        func holds(_ segment: EditSegment) -> Bool {
            segment.sourceID == frame.sourceID && segment.sourceStart - 0.001 <= frame.time && frame.time <= segment.sourceEnd + 0.001
        }
        if let id = frame.segmentID, let index = timeline.index(ofSegment: id), holds(segments[index]) {
            return (index, segments[index])
        }
        guard let index = segments.firstIndex(where: holds) else { return nil }
        return (index, segments[index])
    }

    /// Where `frame` plays in the edit (edited seconds); nil when it was cut out.
    func editedTime(of frame: CoverFrame) -> TimeInterval? {
        guard let (index, segment) = clip(showing: frame) else { return nil }
        let offset = segment.editedOffset(forSource: max(0, frame.time - segment.sourceStart))
        return min(editedDuration, timeline.editedStart(ofSegmentAt: index) + min(offset, segment.duration))
    }

    /// The cover is a frame no clip of the edit shows any more (its part was removed): it is still drawn from its recording,
    /// and Cover says so.
    var coverFrameLeftTheEdit: Bool {
        guard let frame = cover?.source.frame else { return false }
        return clip(showing: frame) == nil
    }
}
