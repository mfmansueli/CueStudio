//
//  TakeEdit+Blur.swift
//  Cue Studio
//

import Foundation

/// Where Blur areas show in the edit: an area is on its footage's own seconds (`BlurRegion`), so it shows wherever those
/// seconds play: every clip of its recording (copies too), a reversed clip of it read backwards, a frame of it frozen, or the
/// pieces of the photo or video over the take it's on.
nonisolated extension TakeEdit {
    /// The photo or video over the take an area is on, when it's on one.
    func media(of region: BlurRegion) -> MediaOverlay? {
        region.target.mediaID.flatMap { id in media.first { $0.id == id } }
    }

    /// Whether the area is on a photo (which has no time: it covers it whole).
    func isOnPhoto(_ region: BlurRegion) -> Bool {
        media(of: region)?.kind == .photo
    }

    /// The second of the footage `target` that the edit shows at `time` (edited seconds); nil where it doesn't show.
    func footageTime(of target: BlurTarget, at time: TimeInterval, in timeline: EditTimeline) -> TimeInterval? {
        if let id = target.mediaID {
            guard let item = media.first(where: { $0.id == id }) else { return nil }
            return item.fileTime(at: time, in: timeline)
        }
        guard !timeline.segments.isEmpty else { return nil }
        let index = timeline.segmentIndex(atEdited: time)
        let segment = timeline.segments[index]
        let start = timeline.editedStart(ofSegmentAt: index)
        guard time >= start - 0.000_1, time <= start + segment.duration + 0.000_1 else { return nil }
        let played = segment.sourceStart + segment.sourceOffset(forEdited: max(0, time - start))
        if segment.sourceID == target.recordingID { return min(played, segment.sourceEnd) }
        guard let source = segment.sourceID.flatMap({ id in sources.first { $0.id == id } }) else { return nil }
        if let reversal = source.reversal, reversal.sourceID == target.recordingID {
            return reversal.span.end - played
        }
        if let still = source.still, still.sourceID == target.recordingID { return still.time }
        return nil
    }

    /// Where the area shows in `timeline` (edited seconds), in order: once per clip (or piece of media) its footage plays in.
    func editedSpans(of region: BlurRegion, in timeline: EditTimeline) -> [TimeSpan] {
        if let id = region.target.mediaID {
            guard let item = media.first(where: { $0.id == id }) else { return [] }
            let pieces = item.pieces(in: timeline)
            if item.kind == .photo { return pieces.map(\.edited) }
            return pieces.compactMap { piece in
                let start = max(region.span.start, piece.fileStart), end = min(region.span.end, piece.fileEnd)
                guard end - start > BlurRegion.negligible else { return nil }
                return TimeSpan(start: piece.edited.start + (start - piece.fileStart), end: piece.edited.start + (end - piece.fileStart))
            }
        }
        var spans: [TimeSpan] = []
        var elapsed: TimeInterval = 0
        for segment in timeline.segments {
            defer { elapsed += segment.duration }
            // The stretch of the recording this clip plays that the area covers, as seconds of the clip's own file.
            let shown: TimeSpan?
            if segment.sourceID == region.target.recordingID {
                shown = TimeSpan(start: max(region.span.start, segment.sourceStart), end: min(region.span.end, segment.sourceEnd))
            } else if let source = segment.sourceID.flatMap({ id in sources.first { $0.id == id } }) {
                if let reversal = source.reversal, reversal.sourceID == region.target.recordingID {
                    // Read backwards: the file's second r shows the recording's second `end - r`.
                    shown = TimeSpan(
                        start: max(reversal.span.end - region.span.end, segment.sourceStart),
                        end: min(reversal.span.end - region.span.start, segment.sourceEnd)
                    )
                } else if let still = source.still, still.sourceID == region.target.recordingID, region.span.contains(still.time) {
                    shown = segment.span
                } else {
                    shown = nil
                }
            } else {
                shown = nil
            }
            guard let shown, shown.duration > BlurRegion.negligible else { continue }
            spans.append(TimeSpan(
                start: elapsed + segment.editedOffset(forSource: shown.start - segment.sourceStart),
                end: elapsed + segment.editedOffset(forSource: shown.end - segment.sourceStart)
            ))
        }
        return spans
    }

    /// The first place the edit shows second `time` of the area's footage (edited seconds); nil when it never does.
    func editedTime(ofFootage time: TimeInterval, of region: BlurRegion, in timeline: EditTimeline) -> TimeInterval? {
        for span in editedSpans(of: region, in: timeline) {
            let probe = (span.start + span.end) / 2
            guard let middle = footageTime(of: region.target, at: probe, in: timeline) else { continue }
            // Walk from the middle of this showing to the moment, at its own pace (reversed footage runs the other way).
            let startFootage = footageTime(of: region.target, at: span.start, in: timeline) ?? middle
            let endFootage = footageTime(of: region.target, at: max(span.start, span.end - 0.000_1), in: timeline) ?? middle
            let low = min(startFootage, endFootage), high = max(startFootage, endFootage)
            guard time >= low - 0.000_1, time <= high + 0.000_1 else { continue }
            guard high - low > 0.000_1 else { return span.start }
            // Bisect: the footage runs one way through a showing.
            var from = span.start, to = span.end
            let rising = endFootage >= startFootage
            for _ in 0..<40 {
                let mid = (from + to) / 2
                let at = footageTime(of: region.target, at: mid, in: timeline) ?? middle
                if (at < time) == rising { from = mid } else { to = mid }
            }
            return (from + to) / 2
        }
        return nil
    }

    /// The areas whose footage the edit shows at `time` (edited seconds), with the second of it there.
    func blurRegions(showingAt time: TimeInterval, in timeline: EditTimeline) -> [(region: BlurRegion, footage: TimeInterval)] {
        blurRegions.compactMap { region in
            guard let footage = footageTime(of: region.target, at: time, in: timeline) else { return nil }
            guard isOnPhoto(region) || region.span.contains(footage) else { return nil }
            return (region, footage)
        }
    }
}
