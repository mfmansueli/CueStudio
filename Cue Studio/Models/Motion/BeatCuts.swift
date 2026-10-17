//
//  BeatCuts.swift
//  Cue Studio
//

import Foundation

/// Cuts on the beats of the creator's music: where the beats fall in the edit, the cuts moved onto the nearest beat (the clip
/// before each cut a little longer or shorter, never past its recording or into the next part of it), and the clips cut on
/// every beat (or every second or fourth). Pure.
nonisolated enum BeatCuts {
    /// How far a cut may move to land on a beat, in seconds.
    static let reach: TimeInterval = 0.5

    /// The beats of `clip` (seconds into its file) where they play in the edit, in order.
    static func editedBeats(of clip: MusicClip, beats: [TimeInterval], editDuration: TimeInterval) -> [TimeInterval] {
        guard let span = clip.span(inEditOf: editDuration) else { return [] }
        return beats.compactMap { beat in
            let time = clip.start + beat - clip.offset
            return time >= span.start - 0.000_1 && time <= span.end + 0.000_1 ? time : nil
        }
    }

    /// The timeline with each cut on the nearest beat within `reach` (left to right: moving a cut moves the ones after it);
    /// nil when no cut can move. Also says how many moved.
    static func movingCuts(of timeline: EditTimeline, onto beats: [TimeInterval]) -> (timeline: EditTimeline, moved: Int)? {
        guard timeline.segments.count > 1, !beats.isEmpty else { return nil }
        var result = timeline
        var moved = 0
        for join in 1..<result.segments.count {
            let cut = result.editedStart(ofSegmentAt: join)
            guard let beat = beats.min(by: { abs($0 - cut) < abs($1 - cut) }), abs(beat - cut) <= reach, abs(beat - cut) > 0.005 else { continue }
            var clip = result.segments[join - 1]
            let wanted = clip.duration + beat - cut
            guard wanted >= EditTimeline.minimumDuration else { continue }
            let end = clip.sourceStart + clip.extendedSourceOffset(forEdited: wanted)
            // Never past the recording, nor into the next part of it that plays (it would show twice).
            var limit = result.duration(ofSource: clip.sourceID)
            if !result.isArranged, join < result.segments.count {
                let next = result.segments[join]
                if next.sourceID == clip.sourceID, next.sourceStart >= clip.sourceEnd - 0.001 { limit = min(limit, next.sourceStart) }
            }
            guard end <= limit + 0.000_1, end > clip.sourceStart else { continue }
            clip.sourceEnd = min(end, limit)
            guard result.replaceSegment(clip) else { continue }
            moved += 1
        }
        return moved > 0 ? (result, moved) : nil
    }

    /// The timeline cut on every `every`-th beat (skipping cuts closer than a clip can be); nil when none can be made. Also says
    /// how many were made.
    static func cutting(_ timeline: EditTimeline, onto beats: [TimeInterval], every: Int) -> (timeline: EditTimeline, cuts: Int)? {
        let picked = beats.enumerated().filter { $0.offset % max(1, every) == 0 }.map(\.element)
        var result = timeline
        var cuts = 0
        for beat in picked where beat > 0.000_1 && beat < result.editedDuration - 0.000_1 {
            let existing = result.segments.indices.map { result.editedStart(ofSegmentAt: $0) }
            guard !existing.contains(where: { abs($0 - beat) < EditTimeline.minimumDuration }) else { continue }
            if result.split(atEdited: beat) { cuts += 1 }
        }
        return cuts > 0 ? (result, cuts) : nil
    }
}
