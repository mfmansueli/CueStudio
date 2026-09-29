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
/// A cut is a division, not a barrier: a handle dragged past one keeps trimming, and the pieces it
/// passes leave the edit with their seams. Each seam carries how the next piece takes over
/// (`EditSegment.transitionIn`), a hard cut unless the creator picks a transition.
///
/// Each piece has a speed (the Speed tool): its length in the edit is its stretch of the recording
/// over its speed, and every mapping between edited seconds and seconds of the recording goes
/// through it.
///
/// Pieces stay in the recording's order, never overlap, and there is always at least one. The
/// first piece's transition is always a hard cut: nothing comes before it.
nonisolated struct EditTimeline: Codable, Hashable, Sendable {
    /// Shortest piece a trim or cut can leave: three frames at 30 fps.
    static let minimumDuration: TimeInterval = 0.1

    /// Length of the original recording.
    private(set) var sourceDuration: TimeInterval
    /// What plays, in order.
    private(set) var segments: [EditSegment] {
        didSet {
            // A piece that becomes the first (a trim or a delete took the one before) has no seam.
            if let first = segments.first, first.transitionIn != .hardCut { segments[0].transitionIn = .hardCut }
        }
    }

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
            if segment.sourceLength >= Self.minimumDuration - 0.000_1 { kept.append(segment) }
        }
        if !kept.isEmpty { kept[0].transitionIn = .hardCut }
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

    /// The kept spans with pieces that follow on in the recording at the same speed joined: a cut
    /// that removed nothing leaves no seam.
    var continuousSpans: [TimeSpan] {
        var result: [TimeSpan] = []
        for (index, segment) in segments.enumerated() {
            if isSeamless(index) {
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

    /// Whether the piece at `index` plays on from the one before it with nothing to hear or see at
    /// the seam: nothing was removed and both play at the same speed.
    func isSeamless(_ index: Int) -> Bool {
        continuesFromPrevious(index) && segments[index].speed == segments[index - 1].speed
    }

    /// Edited seconds the trimmed start takes in `reachable` (where the preview's item begins):
    /// the edit starts this far into it.
    var reachableLeadIn: TimeInterval {
        trimStart / segments[0].speed
    }

    /// Whether any piece plays at another speed than filmed.
    var hasSpeedChanges: Bool {
        segments.contains { abs($0.speed - 1) > 0.000_1 }
    }

    /// Where a stretch of the recording plays in the edit: from where its start plays (or where the
    /// edit picks up after it) to where its end does. Nil when nothing of it plays. Texts, media and
    /// captions are pinned to the recording this way, so they stay on what is being said when
    /// something before them is cut or sped up.
    func editedSpan(forSource span: TimeSpan) -> TimeSpan? {
        let start = editedTime(following: span.start)
        let end = editedTime(following: span.end)
        guard end - start > 0.000_1 else { return nil }
        return TimeSpan(start: start, end: end)
    }

    /// The stretch of the recording that plays between two edited moments: how an overlay placed
    /// on the edit is pinned to the recording.
    func sourceSpan(forEdited span: TimeSpan) -> TimeSpan {
        TimeSpan(start: sourceTime(forEdited: span.start), end: sourceTime(forEdited: span.end))
    }

    /// How the piece at `index` takes over from the one before it (the seam before it). Always a
    /// hard cut for the first piece.
    func transition(atJoin index: Int) -> EditTransition {
        index > 0 && index < segments.count ? segments[index].transitionIn : .hardCut
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
        return min(max(segment.sourceStart, segment.sourceStart + offset * segment.speed), segment.sourceEnd)
    }

    /// Where a moment of the recording plays in the edit, or nil when it was cut. The end of the
    /// last piece counts, so the end handle maps to the end of the edit.
    func editedTime(forSource time: TimeInterval) -> TimeInterval? {
        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let isLast = index == segments.count - 1
            let startsBefore = time >= segment.sourceStart - 0.000_001
            let endsAfter = time < segment.sourceEnd || (isLast && time <= segment.sourceEnd + 0.000_001)
            if startsBefore, endsAfter { return elapsed + max(0, time - segment.sourceStart) / segment.speed }
            elapsed += segment.duration
        }
        return nil
    }

    /// Where a moment of the recording plays in the edit; when it was cut, where the edit picks up
    /// after it (or its end).
    func editedTime(following source: TimeInterval) -> TimeInterval {
        if let edited = editedTime(forSource: source) { return edited }
        if let next = segments.firstIndex(where: { $0.sourceStart >= source }) {
            return editedStart(ofSegmentAt: next)
        }
        return editedDuration
    }

    /// The playhead after an edit: `time` in `previous`, moved to the same moment of the recording
    /// here. When that moment was cut, to where the edit picks up after it (or to its end).
    func editedTime(matching time: TimeInterval, in previous: EditTimeline) -> TimeInterval {
        editedTime(following: previous.sourceTime(forEdited: time))
    }

    /// `count` moments of the recording spread evenly across the edit, one from the middle of
    /// each equal stretch: what a filmstrip of the edited video shows. Cut pieces never appear.
    func sourceTimes(evenlyAcross count: Int) -> [TimeInterval] {
        let length = editedDuration
        guard count > 0, length > 0 else { return [] }
        return (0..<count).map { sourceTime(forEdited: length * (Double($0) + 0.5) / Double(count)) }
    }

    /// The parts of the recording that play between two edited moments, in order: what "Remove
    /// part" takes out. A range across a cut gives one span per piece.
    func sourceSpans(forEdited range: ClosedRange<TimeInterval>) -> [TimeSpan] {
        var spans: [TimeSpan] = []
        var elapsed: TimeInterval = 0
        for segment in segments {
            let start = max(range.lowerBound, elapsed)
            let end = min(range.upperBound, elapsed + segment.duration)
            if end > start {
                spans.append(TimeSpan(
                    start: segment.sourceStart + (start - elapsed) * segment.speed,
                    end: min(segment.sourceEnd, segment.sourceStart + (end - elapsed) * segment.speed)
                ))
            }
            elapsed += segment.duration
        }
        return spans
    }

    /// Whether nothing of `span` plays any more.
    func isRemoved(_ span: TimeSpan) -> Bool {
        !segments.contains { $0.span.overlaps(span) }
    }

    // MARK: - Editing

    /// Moves the start handle, from the beginning of the recording to just before the edit ends.
    /// A cut is no barrier: past the end of the first piece, the pieces the handle passes leave
    /// the edit, and so do the seams between them. Across a cut that removed nothing the handle
    /// lands exactly on `time`; across a removed part, at the start of the piece after it.
    mutating func trimStart(to time: TimeInterval) {
        let last = segments.count - 1
        let target = min(max(0, time), max(0, segments[last].sourceEnd - Self.minimumDuration))
        var first = 0
        while first < last, segments[first].sourceEnd - target < Self.minimumDuration - 0.000_1 { first += 1 }
        guard first > 0 else {
            segments[0].sourceStart = target
            return
        }
        // The rest of a passed piece that runs straight on into this one is the same recording.
        let runsOn = continuesFromPrevious(first)
        var trimmed = Array(segments[first...])
        trimmed[0].sourceStart = runsOn ? target : max(trimmed[0].sourceStart, target)
        segments = trimmed
    }

    /// Moves the end handle, from just after the edit starts to the end of the recording. Like
    /// the start handle, it trims straight through cuts: the pieces it passes leave the edit.
    mutating func trimEnd(to time: TimeInterval) {
        let target = max(min(sourceDuration, time), min(sourceDuration, segments[0].sourceStart + Self.minimumDuration))
        var last = segments.count - 1
        while last > 0, target - segments[last].sourceStart < Self.minimumDuration - 0.000_1 { last -= 1 }
        guard last < segments.count - 1 else {
            segments[last].sourceEnd = target
            return
        }
        let runsOn = continuesFromPrevious(last + 1)
        var trimmed = Array(segments[...last])
        trimmed[last].sourceEnd = runsOn ? target : min(trimmed[last].sourceEnd, target)
        segments = trimmed
    }

    /// Sets how the piece at `index` takes over from the one before it. False, and no change,
    /// for the first piece (no seam) or when it's already that transition.
    @discardableResult
    mutating func setTransition(_ transition: EditTransition, atJoin index: Int) -> Bool {
        guard index > 0, index < segments.count, segments[index].transitionIn != transition else { return false }
        segments[index].transitionIn = transition
        return true
    }

    /// Cuts the piece playing at `time` (edited seconds) in two. False when either side would be
    /// shorter than `minimumDuration`: at an edge or right next to another cut.
    @discardableResult
    mutating func split(atEdited time: TimeInterval) -> Bool {
        let index = segmentIndex(atEdited: time)
        let segment = segments[index]
        let offset = time - editedStart(ofSegmentAt: index)
        guard offset >= Self.minimumDuration, segment.duration - offset >= Self.minimumDuration else { return false }
        let cut = segment.sourceStart + offset * segment.speed
        segments[index].sourceEnd = cut
        segments.insert(EditSegment(sourceStart: cut, sourceEnd: segment.sourceEnd, speed: segment.speed), at: index + 1)
        return true
    }

    /// Plays the piece at `index` at `speed`. False, and no change, when it already does.
    @discardableResult
    mutating func setSpeed(_ speed: Double, forSegmentAt index: Int) -> Bool {
        let speed = EditSegment.clampedSpeed(speed)
        guard segments.indices.contains(index), abs(segments[index].speed - speed) > 0.000_1 else { return false }
        segments[index].speed = speed
        return true
    }

    /// Plays every piece at `speed`. False, and no change, when they all already do.
    @discardableResult
    mutating func setSpeed(_ speed: Double) -> Bool {
        var changed = false
        for index in segments.indices where setSpeed(speed, forSegmentAt: index) { changed = true }
        return changed
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
                // The first piece left keeps the seam before it; new seams start as hard cuts.
                result.append(EditSegment(
                    id: offset == 0 ? segment.id : UUID(), span: piece,
                    transitionIn: offset == 0 ? segment.transitionIn : .hardCut, speed: segment.speed
                ))
            }
        }
        guard !result.isEmpty, result.map(\.span) != keptSpans else { return false }
        segments = result
        return true
    }

    /// "Remove part": takes out what plays between two edited moments (internally, two cuts and a
    /// removal). False, and no change, when nothing would be left or the range is empty.
    @discardableResult
    mutating func removeEdited(_ range: ClosedRange<TimeInterval>) -> Bool {
        remove(sourceSpans(forEdited: range))
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
        // What comes back plays at the speed of the piece it joins (the one before it, else after).
        let restored = TimeSpan.merged(missing).map { span in
            let neighbor = segments.last { $0.sourceEnd <= span.start + 0.001 } ?? segments.first { $0.sourceStart >= span.end - 0.001 }
            return Piece(segment: EditSegment(span: span, speed: neighbor?.speed ?? 1), isRestored: true)
        }
        let entries = (segments.map { Piece(segment: $0, isRestored: false) } + restored)
            .sorted { $0.segment.sourceStart < $1.segment.sourceStart }
        var joined: [Piece] = []
        for entry in entries {
            // `isRestored` on a joined piece says whether its end came back, so the next seam is
            // closed only when one side of it was restored.
            if let last = joined.last, abs(last.segment.sourceEnd - entry.segment.sourceStart) < 0.001, last.isRestored || entry.isRestored,
               last.segment.speed == entry.segment.speed {
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
