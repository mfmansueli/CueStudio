//
//  VoiceOverClip.swift
//  Cue Studio
//

import Foundation

/// A narration recorded over the edit. It starts on a moment of the recording (`anchor`), so it
/// stays with what it talks about when something before it is cut, and plays on from there (its
/// ends as trimmed on the timeline): cuts under it never chop the voice. What runs past the end of
/// the edit isn't heard.
nonisolated struct VoiceOverClip: Codable, Hashable, Identifiable, Sendable {
    static let volumeRange: ClosedRange<Double> = 0...2

    var id = UUID()
    /// The recording's name in `EditMediaFiles`.
    var fileName: String
    /// Length of the recording.
    var duration: TimeInterval
    /// Second of the take it starts on.
    var anchor: TimeInterval
    var volume: Double = 1
    /// In an arranged edit, the piece it starts on (`anchor` is then of that piece's recording).
    var clipAnchor: ClipAnchor?
    /// Seconds into the recording it starts from (its start trimmed); nil from the beginning.
    var offset: TimeInterval?
    /// How long it plays (its end trimmed); nil to the end of the recording.
    var length: TimeInterval?

    /// How long it plays: the recording after `offset`, up to `length`.
    var playedDuration: TimeInterval {
        let rest = max(0, duration - (offset ?? 0))
        return min(rest, length ?? rest)
    }

    init(fileName: String, duration: TimeInterval, anchor: TimeInterval) {
        self.fileName = fileName
        self.duration = max(0, duration)
        self.anchor = max(0, anchor)
    }

    /// Where it plays in `timeline` (edited seconds), cut at the end of the edit; nil when none of
    /// it is heard.
    func editedSpan(in timeline: EditTimeline) -> TimeSpan? {
        let start = clipAnchor
            .flatMap { timeline.editedSpan(forSource: TimeSpan(start: anchor, end: anchor + 0.05), anchoredTo: $0)?.start }
            ?? timeline.editedTime(following: anchor)
        let end = min(start + playedDuration, timeline.editedDuration)
        guard end - start > 0.05 else { return nil }
        return TimeSpan(start: start, end: end)
    }
}
