//
//  MusicPlacement.swift
//  Cue Studio
//

import Foundation

/// Where new music goes on the music track: at the playhead, in the free room around it. Clips
/// don't pile up on one track, so a playhead over a clip moves to its end, and the new one stops
/// where the next begins. Pure, so the rule is tested without the editor.
nonisolated enum MusicPlacement {
    /// The room the new clip can take, in edited seconds, or nil when there's no room at all
    /// (the playhead is at the end, or the free stretch is shorter than the least a clip plays).
    static func slot(playhead: TimeInterval, editDuration: TimeInterval, occupied: [TimeSpan]) -> TimeSpan? {
        guard editDuration > 0 else { return nil }
        let sorted = occupied.sorted { $0.start < $1.start }
        var start = min(max(0, playhead), editDuration)
        for span in sorted where start >= span.start - 0.05 && start < span.end {
            start = span.end
        }
        let end = min(editDuration, sorted.first { $0.start > start }?.start ?? editDuration)
        guard end - start >= MusicClip.minimumDuration else { return nil }
        return TimeSpan(start: start, end: end)
    }
}
