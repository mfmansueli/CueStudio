//
//  CaptionTimelineMapping.swift
//  Cue Studio
//

import Foundation

/// Maps source audio intervals into retained pieces, clamping both ends before applying speed.
/// Adjacent uninterrupted pieces share a window, so a harmless split cannot restart a caption.
nonisolated enum CaptionTimelineMapping {
    private struct Window {
        let id: UUID
        let sourceID: UUID?
        var span: TimeSpan
        let speed: Double
        let editedStart: Double

        func edited(_ source: Double) -> Double { editedStart + (source - span.start) / speed }
    }

    static func instances(_ cues: [CaptionCue], in timeline: EditTimeline) -> [(line: CaptionCue, cueID: UUID)] {
        var windows: [Window] = []
        for (index, segment) in timeline.segments.enumerated() {
            if let last = windows.last, last.sourceID == segment.sourceID,
               abs(last.span.end - segment.sourceStart) < 0.000_001, last.speed == segment.speed {
                windows[windows.count - 1].span.end = segment.sourceEnd
            } else {
                windows.append(Window(id: segment.id, sourceID: segment.sourceID, span: segment.span, speed: segment.speed,
                                      editedStart: timeline.editedStart(ofSegmentAt: index)))
            }
        }
        var result: [(line: CaptionCue, cueID: UUID)] = []
        for cue in cues {
            var first = true
            for window in windows where window.sourceID == cue.sourceID && window.span.overlaps(cue.span) {
                guard var mapped = mapped(cue, into: window) else { continue }
                if !first { mapped.id = instanceID(cue.id, window.id) }
                first = false
                result.append((mapped, cue.id))
            }
        }
        return result.sorted { $0.line.start < $1.line.start }
    }

    private static func mapped(_ cue: CaptionCue, into window: Window) -> CaptionCue? {
        let start = max(cue.start, window.span.start)
        let end = min(cue.end, window.span.end)
        guard end > start else { return nil }
        var mapped = cue
        mapped.start = window.edited(start)
        mapped.end = window.edited(end)
        if !cue.hasWordTiming, start > cue.start || end < cue.end {
            // The retained time is known, but which words survive a partial segment isn't.
            // Keep the source intact and explicitly ask for review instead of inventing alignment.
            mapped.needsTimingReview = true
        }
        if !cue.words.isEmpty {
            let words = cue.words.compactMap { word -> CaptionWord? in
                let middle = (word.start + word.end) / 2
                // Estimated words have only a segment interval: no invented word boundary.
                guard word.isEstimated || window.span.contains(middle) else { return nil }
                let from = max(start, word.start)
                let until = min(end, word.end)
                guard until > from else { return nil }
                return CaptionWord(text: word.text, start: window.edited(from), end: window.edited(until), isEstimated: word.isEstimated)
            }
            guard let first = words.first, let last = words.last else { return nil }
            mapped.words = words
            if words.count != cue.words.count { mapped.text = CaptionText.joined(words.map(\.text)) }
            mapped.start = max(mapped.start, first.start)
            mapped.end = min(mapped.end, last.end)
        }
        return mapped.end > mapped.start ? mapped : nil
    }

    private static func instanceID(_ cue: UUID, _ piece: UUID) -> UUID {
        let a = cue.uuid
        let b = piece.uuid
        return UUID(uuid: (
            a.0 ^ b.0, a.1 ^ b.1, a.2 ^ b.2, a.3 ^ b.3, a.4 ^ b.4, a.5 ^ b.5, a.6 ^ b.6, a.7 ^ b.7,
            a.8 ^ b.8, a.9 ^ b.9, a.10 ^ b.10, a.11 ^ b.11, a.12 ^ b.12, a.13 ^ b.13, a.14 ^ b.14, a.15 ^ b.15
        ))
    }
}
