//
//  EditTimeline.swift
//  Cue Studio
//

import Foundation

/// The edited video as pieces of the original recording, played one after the other. The
/// recording itself never changes: Trim moves the outer ends, Cut splits a piece in two, Remove
/// drops one, and Clean Up takes spans out the same way. A plain value, so every edit is a new
/// state undo can return to, and the preview and the export play exactly the same pieces.
///
/// Pieces stay in the recording's order, never overlap, and there is always at least one.
nonisolated struct EditTimeline: Codable, Hashable, Sendable {
    /// Shortest piece a trim or cut can leave: three frames at 30 fps.
    static let minimumDuration: TimeInterval = 0.1

    /// Length of the original recording.
    private(set) var sourceDuration: TimeInterval
    /// What plays, in order.
    private(set) var segments: [EditSegment]

    /// The whole recording, untouched.
    init(sourceDuration: TimeInterval) {
        let duration = max(0, sourceDuration)
        self.sourceDuration = duration
        segments = [EditSegment(sourceStart: 0, sourceEnd: duration)]
    }

    /// Pieces for `spans`, clamped to the recording, in order and without overlaps; the whole
    /// recording when none is long enough to keep.
    init(sourceDuration: TimeInterval, keeping spans: [TimeSpan]) {
        self.init(sourceDuration: sourceDuration, segments: spans.map { EditSegment(span: $0) })
    }

    private init(sourceDuration: TimeInterval, segments: [EditSegment]) {
        let duration = max(0, sourceDuration)
        self.sourceDuration = duration
        var kept: [EditSegment] = []
        for var segment in segments.sorted(by: { $0.sourceStart < $1.sourceStart }) {
            segment.sourceStart = max(segment.sourceStart, kept.last?.sourceEnd ?? 0)
            segment.sourceEnd = min(segment.sourceEnd, duration)
            if segment.duration >= Self.minimumDuration - 0.000_1 { kept.append(segment) }
        }
        self.segments = kept.isEmpty ? [EditSegment(sourceStart: 0, sourceEnd: duration)] : kept
    }

    /// Decoding goes through the same checks, so a damaged draft can't break the rules above.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sourceDuration: try container.decode(TimeInterval.self, forKey: .sourceDuration),
            segments: try container.decode([EditSegment].self, forKey: .segments)
        )
    }

    // MARK: - Reading

    var editedDuration: TimeInterval { segments.reduce(0) { $0 + $1.duration } }

    var keptSpans: [TimeSpan] { segments.map(\.span) }

    /// Where the start handle is, in seconds of the recording.
    var trimStart: TimeInterval { segments[0].sourceStart }

    /// Where the end handle is, in seconds of the recording.
    var trimEnd: TimeInterval { segments[segments.count - 1].sourceEnd }

    /// Before the start handle: what dragging it back can bring in.
    var head: TimeSpan { TimeSpan(start: 0, end: trimStart) }

    /// After the end handle.
    var tail: TimeSpan { TimeSpan(start: trimEnd, end: sourceDuration) }

    /// One piece that is the whole recording.
    var isWhole: Bool {
        segments.count == 1 && trimStart <= 0.000_1 && trimEnd >= sourceDuration - 0.000_1
    }

    /// The pieces with the first grown back to the start of the recording and the last to its end:
    /// everything the handles can reach. The preview plays this and holds playback between the
    /// handles, so dragging a handle scrubs real frames without rebuilding anything.
    var reachable: EditTimeline {
        var copy = self
        copy.segments[0].sourceStart = 0
        copy.segments[copy.segments.count - 1].sourceEnd = sourceDuration
        return copy
    }

    /// The kept spans with pieces that follow on in the recording joined: a cut that removed
    /// nothing leaves no seam.
    var continuousSpans: [TimeSpan] {
        var result: [TimeSpan] = []
        for (index, segment) in segments.enumerated() {
            if continuesFromPrevious(index) {
                result[result.count - 1].end = segment.sourceEnd
            } else {
                result.append(segment.span)
            }
        }
        return result
    }

    /// Whether the piece at `index` picks up exactly where the one before it ends (a cut that
    /// removed nothing).
    func continuesFromPrevious(_ index: Int) -> Bool {
        index > 0 && index < segments.count && abs(segments[index].sourceStart - segments[index - 1].sourceEnd) < 0.001
    }

    func segment(id: UUID) -> EditSegment? {
        segments.first { $0.id == id }
    }

    func index(ofSegment id: UUID) -> Int? {
        segments.firstIndex { $0.id == id }
    }

    /// Edited seconds where the piece at `index` starts.
    func editedStart(ofSegmentAt index: Int) -> TimeInterval {
        segments.prefix(max(0, index)).reduce(0) { $0 + $1.duration }
    }

    /// The piece playing at `time` (edited seconds); at a cut, the piece that starts there.
    func segmentIndex(atEdited time: TimeInterval) -> Int {
        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            elapsed += segment.duration
            if time < elapsed - 0.000_001 { return index }
        }
        return segments.count - 1
    }

    /// The moment of the recording shown at `time` (edited seconds).
    func sourceTime(forEdited time: TimeInterval) -> TimeInterval {
        let index = segmentIndex(atEdited: time)
        let segment = segments[index]
        let offset = time - editedStart(ofSegmentAt: index)
        return min(max(segment.sourceStart, segment.sourceStart + offset), segment.sourceEnd)
    }

    /// Where a moment of the recording plays in the edit, or nil when it was cut. The end of the
    /// last piece counts, so the end handle maps to the end of the edit.
    func editedTime(forSource time: TimeInterval) -> TimeInterval? {
        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let isLast = index == segments.count - 1
            let startsBefore = time >= segment.sourceStart - 0.000_001
            let endsAfter = time < segment.sourceEnd || (isLast && time <= segment.sourceEnd + 0.000_001)
            if startsBefore, endsAfter { return elapsed + max(0, time - segment.sourceStart) }
            elapsed += segment.duration
        }
        return nil
    }

    /// The playhead after an edit: `time` in `previous`, moved to the same moment of the recording
    /// here. When that moment was cut, to where the edit picks up after it (or to its end).
    func editedTime(matching time: TimeInterval, in previous: EditTimeline) -> TimeInterval {
        let source = previous.sourceTime(forEdited: time)
        if let edited = editedTime(forSource: source) { return edited }
        if let next = segments.firstIndex(where: { $0.sourceStart >= source }) {
            return editedStart(ofSegmentAt: next)
        }
        return editedDuration
    }

    /// Whether nothing of `span` plays any more.
    func isRemoved(_ span: TimeSpan) -> Bool {
        !segments.contains { $0.span.overlaps(span) }
    }

    // MARK: - Editing

    /// Moves the start handle: the first piece's start, from the beginning of the recording to
    /// just before that piece ends.
    mutating func trimStart(to time: TimeInterval) {
        let latest = max(0, segments[0].sourceEnd - Self.minimumDuration)
        segments[0].sourceStart = min(max(0, time), latest)
    }

    /// Moves the end handle: the last piece's end, from just after that piece starts to the end of
    /// the recording.
    mutating func trimEnd(to time: TimeInterval) {
        let last = segments.count - 1
        let earliest = min(sourceDuration, segments[last].sourceStart + Self.minimumDuration)
        segments[last].sourceEnd = max(min(sourceDuration, time), earliest)
    }

    /// Cuts the piece playing at `time` (edited seconds) in two. False when either side would be
    /// shorter than `minimumDuration`: at an edge or right next to another cut.
    @discardableResult
    mutating func split(atEdited time: TimeInterval) -> Bool {
        let index = segmentIndex(atEdited: time)
        let segment = segments[index]
        let offset = time - editedStart(ofSegmentAt: index)
        guard offset >= Self.minimumDuration, segment.duration - offset >= Self.minimumDuration else { return false }
        let cut = segment.sourceStart + offset
        segments[index].sourceEnd = cut
        segments.insert(EditSegment(sourceStart: cut, sourceEnd: segment.sourceEnd), at: index + 1)
        return true
    }

    /// Drops a piece. False when it is the only one left: an edit always plays something.
    @discardableResult
    mutating func removeSegment(id: UUID) -> Bool {
        guard segments.count > 1, let index = index(ofSegment: id) else { return false }
        segments.remove(at: index)
        return true
    }

    /// Takes `spans` of the recording out of the pieces (Clean Up); slivers shorter than
    /// `minimumDuration` go with them. False, and no change, when nothing would be left or
    /// nothing changes.
    @discardableResult
    mutating func remove(_ spans: [TimeSpan]) -> Bool {
        var result: [EditSegment] = []
        for segment in segments {
            let pieces = segment.span.subtracting(spans).filter { $0.duration >= Self.minimumDuration }
            for (offset, piece) in pieces.enumerated() {
                result.append(EditSegment(id: offset == 0 ? segment.id : UUID(), span: piece))
            }
        }
        guard !result.isEmpty, result.map(\.span) != keptSpans else { return false }
        segments = result
        return true
    }

    /// Puts back what was removed of `spans` between the handles, joined to the pieces it
    /// touches: the seams it closes disappear, cuts made by hand stay.
    mutating func restore(_ spans: [TimeSpan]) {
        let missing = spans
            .map { TimeSpan(start: max($0.start, trimStart), end: min($0.end, trimEnd)) }
            .filter { $0.duration > 0.000_1 }
            .flatMap { $0.subtracting(keptSpans) }
            .filter { $0.duration > 0.000_1 }
        guard !missing.isEmpty else { return }
        let entries = (segments.map { Piece(segment: $0, isRestored: false) }
            + TimeSpan.merged(missing).map { Piece(segment: EditSegment(span: $0), isRestored: true) })
            .sorted { $0.segment.sourceStart < $1.segment.sourceStart }
        var joined: [Piece] = []
        for entry in entries {
            // `isRestored` on a joined piece says whether its end came back, so the next seam is
            // closed only when one side of it was restored.
            if let last = joined.last, abs(last.segment.sourceEnd - entry.segment.sourceStart) < 0.001, last.isRestored || entry.isRestored {
                joined[joined.count - 1].segment.sourceEnd = entry.segment.sourceEnd
                joined[joined.count - 1].isRestored = entry.isRestored
            } else {
                joined.append(entry)
            }
        }
        segments = joined.map(\.segment)
    }

    /// Fits the pieces to the recording's real length (a take's saved length can be a little
    /// off): nothing past the end, and an end that was never trimmed stays at the end.
    func fitted(toSourceDuration duration: TimeInterval) -> EditTimeline {
        guard abs(duration - sourceDuration) > 0.001 else { return self }
        var segments = segments
        if abs(trimEnd - sourceDuration) < 0.001 { segments[segments.count - 1].sourceEnd = duration }
        return EditTimeline(sourceDuration: duration, segments: segments)
    }

    private struct Piece {
        var segment: EditSegment
        var isRestored: Bool
    }
}
