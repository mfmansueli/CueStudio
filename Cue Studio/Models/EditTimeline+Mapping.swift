//
//  EditTimeline+Mapping.swift
//  Cue Studio
//

import Foundation

/// Time in the recording ↔ time in the edit, the way the editor names it: texts, captions and
/// photos are kept in the recording's seconds and land in the edit through here, so cutting a part
/// takes what is said in it along (a line cut entirely is hidden, never deleted: undo brings it
/// back).
nonisolated extension EditTimeline {
    /// How a moment of the recording that no longer plays maps to the edit.
    enum SourceMapping: Sendable {
        /// Only moments that still play.
        case exact
        /// Where the edit picks up after it.
        case forward
        /// Where the edit was before it.
        case backward
    }

    /// Where `time` (seconds of the recording `source`; nil: the take) plays in the edit. For a
    /// moment that was cut, `mode` says where it goes; nil when there's nowhere (nothing after or
    /// before it, or `exact`).
    func sourceToEdited(_ time: TimeInterval, mode: SourceMapping, in source: UUID? = nil) -> TimeInterval? {
        if let edited = editedTime(forSource: time, in: source) { return edited }
        var best: (index: Int, distance: TimeInterval)?
        for (index, segment) in segments.enumerated() where segment.sourceID == source {
            switch mode {
            case .exact: return nil
            case .forward where segment.sourceStart > time:
                let distance = segment.sourceStart - time
                if best.map({ distance < $0.distance }) ?? true { best = (index, distance) }
            case .backward where segment.sourceEnd < time:
                let distance = time - segment.sourceEnd
                if best.map({ distance < $0.distance }) ?? true { best = (index, distance) }
            default: break
            }
        }
        guard let best else { return nil }
        let start = editedStart(ofSegmentAt: best.index)
        return mode == .forward ? start : start + segments[best.index].duration
    }

    /// The moment of the recording shown at `time` (edited seconds).
    func editedToSource(_ time: TimeInterval) -> TimeInterval {
        sourceTime(forEdited: time)
    }

    /// Where something kept between `start` and `end` (seconds of the recording) shows in the edit:
    /// from where its start plays (or the edit picks up after it) to where its end plays (or the
    /// edit was before it). Nil when less than `minimumShown` of it is left.
    func span(_ start: TimeInterval, _ end: TimeInterval, in source: UUID? = nil) -> ClosedRange<TimeInterval>? {
        guard let from = sourceToEdited(start, mode: .forward, in: source),
              let until = sourceToEdited(end, mode: .backward, in: source),
              until - from > Self.minimumShown else { return nil }
        return from...until
    }

    /// Less than this of something left in the edit doesn't show.
    static let minimumShown: TimeInterval = 0.08

    /// Takes `start`…`end` of the take's recording out of every clip that plays it (a pause, a
    /// mistake). False, and no change, when nothing changes or nothing would be left.
    @discardableResult
    mutating func cutRange(_ start: TimeInterval, _ end: TimeInterval) -> Bool {
        guard end > start else { return false }
        return remove([TimeSpan(start: start, end: end)])
    }
}
