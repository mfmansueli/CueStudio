//
//  TakeEdit.swift
//  Cue Studio
//

import Foundation

/// Quick edit as a recipe applied on top of the original recording, which is never changed: trim,
/// split and delete sections, silences, audio, look, crop and captions. Preview and export render
/// the same recipe, and the take can be edited again from where it was left.
nonisolated struct TakeEdit: Codable, Hashable, Sendable {
    static let volumeRange: ClosedRange<Double> = 0...1.5
    static let adjustmentRange: ClosedRange<Double> = -100...100
    static let cropOffsetRange: ClosedRange<Double> = -1...1
    /// Splits closer than this to an edge or another split are ignored.
    static let minimumSection: TimeInterval = 0.5

    /// A section of the timeline between two cuts, for the trim strip.
    struct Segment: Hashable, Sendable {
        var span: TimeSpan
        var isRemoved: Bool
    }

    /// Length of the original recording.
    var sourceDuration: TimeInterval

    // MARK: Trim
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval
    /// Cut points inside the trim, in the original's seconds.
    var splits: [TimeInterval] = []
    /// Sections deleted from the timeline.
    var removed: [TimeSpan] = []
    /// Pauses found by "Remove silences"; cut only while `removesSilences` is on.
    var silences: [TimeSpan] = []
    var removesSilences = false

    // MARK: Audio
    /// 0 to 1.5 (150%).
    var volume: Double = 1
    var enhancesVoice = true
    var reducesNoise = false

    // MARK: Look
    var exposure: Double = 0
    var contrast: Double = 0
    var warmth: Double = 0
    var filter: VideoFilter = .original

    // MARK: Crop
    var aspect: AspectRatio
    /// Where the crop sits inside the recording, -1 (top or left) to 1 (bottom or right).
    var cropOffset: Double = 0

    // MARK: Captions
    var showsCaptions = false
    var captionStyle: CaptionStyle = .bold
    var captionPosition: CaptionPosition = .bottom
    /// Timed to the original recording.
    var captions: [CaptionCue] = []

    init(sourceDuration: TimeInterval, aspect: AspectRatio) {
        self.sourceDuration = sourceDuration
        trimEnd = sourceDuration
        self.aspect = aspect
    }

    // MARK: - Timeline

    /// The trim cut into sections at each split, with deleted ones flagged.
    var segments: [Segment] {
        let cuts = splits.filter { $0 > trimStart + Self.minimumSection / 2 && $0 < trimEnd - Self.minimumSection / 2 }.sorted()
        let points = [trimStart] + cuts + [trimEnd]
        return zip(points, points.dropFirst()).map { start, end in
            let span = TimeSpan(start: start, end: end)
            return Segment(span: span, isRemoved: removed.contains(span))
        }
    }

    /// What plays, in order: the kept sections minus the silences when they are removed.
    var keptSpans: [TimeSpan] {
        var spans = segments.filter { !$0.isRemoved }.map(\.span)
        if removesSilences {
            spans = spans.flatMap { Self.subtract(silences, from: $0) }
        }
        return Self.merged(spans.filter { $0.duration > 0.05 })
    }

    var editedDuration: TimeInterval {
        keptSpans.reduce(0) { $0 + $1.duration }
    }

    /// Adds a cut at `time`. False when it is too close to an edge or another cut.
    @discardableResult
    mutating func split(at time: TimeInterval) -> Bool {
        guard time > trimStart + Self.minimumSection, time < trimEnd - Self.minimumSection,
              !splits.contains(where: { abs($0 - time) < Self.minimumSection })
        else { return false }
        splits.append(time)
        return true
    }

    /// Deletes the section under `time`. False when it would leave nothing to play.
    @discardableResult
    mutating func removeSegment(containing time: TimeInterval) -> Bool {
        let segments = segments
        guard let segment = segments.first(where: { !$0.isRemoved && $0.span.contains(time) }),
              segments.filter({ !$0.isRemoved }).count > 1
        else { return false }
        removed.append(segment.span)
        return true
    }

    /// Moves the trim, keeping at least `minimumSection` between the handles.
    mutating func setTrim(start: TimeInterval? = nil, end: TimeInterval? = nil) {
        if let start {
            trimStart = min(max(0, start), trimEnd - Self.minimumSection)
        }
        if let end {
            trimEnd = max(min(sourceDuration, end), trimStart + Self.minimumSection)
        }
    }

    /// Where a moment of the original lands in the edited video, or nil when it was cut.
    func editedTime(forSource time: TimeInterval) -> TimeInterval? {
        var elapsed: TimeInterval = 0
        for span in keptSpans {
            if span.contains(time) { return elapsed + time - span.start }
            elapsed += span.duration
        }
        return nil
    }

    /// Captions timed to the edited video; lines said in cut sections disappear.
    var editedCaptions: [CaptionCue] {
        captions.compactMap { cue in
            guard let start = editedTime(forSource: cue.start) ?? editedTime(forSource: cue.end - 0.05) else { return nil }
            let end = editedTime(forSource: cue.end - 0.05).map { $0 + 0.05 } ?? start + (cue.end - cue.start)
            return CaptionCue(text: cue.text, start: start, end: max(start + 0.2, end))
        }
    }

    /// Whether anything visible or audible differs from the original.
    func differs(from original: AspectRatio) -> Bool {
        var untouched = TakeEdit(sourceDuration: sourceDuration, aspect: original)
        untouched.captions = captions
        untouched.silences = silences
        return self != untouched
    }

    // MARK: - Spans

    static func subtract(_ holes: [TimeSpan], from span: TimeSpan) -> [TimeSpan] {
        var pieces = [span]
        for hole in holes.sorted(by: { $0.start < $1.start }) {
            pieces = pieces.flatMap { piece -> [TimeSpan] in
                guard hole.end > piece.start, hole.start < piece.end else { return [piece] }
                var result: [TimeSpan] = []
                if hole.start > piece.start { result.append(TimeSpan(start: piece.start, end: hole.start)) }
                if hole.end < piece.end { result.append(TimeSpan(start: hole.end, end: piece.end)) }
                return result
            }
        }
        return pieces
    }

    static func merged(_ spans: [TimeSpan]) -> [TimeSpan] {
        var result: [TimeSpan] = []
        for span in spans.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, span.start <= last.end + 0.001 {
                result[result.count - 1].end = max(last.end, span.end)
            } else {
                result.append(span)
            }
        }
        return result
    }
}
