//
//  ObjectTracking.swift
//  Cue Studio
//

import Foundation

/// Follows an object through a recording (Track: a text or photo that follows something in the video).
nonisolated protocol ObjectTracking: Sendable {
    /// Where the object in `box` (the upright frame, at `time`) is, frame by frame, from `time` to `until` (earlier when
    /// `until` is before `time`: the recording is followed backwards). Stops where the object is lost. `progress` hears how
    /// far it is, 0 to 1. Throws on cancellation or an unreadable recording.
    func track(
        videoAt url: URL, box: NormalizedBox, at time: TimeInterval, until: TimeInterval, progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TrackSample]
}
