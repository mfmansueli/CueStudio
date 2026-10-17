//
//  TrackSample.swift
//  Cue Studio
//

import Foundation

/// Where the object a text or a photo follows is at a moment of its recording: its box on the upright frame (fractions from
/// the top left) and how sure Vision is (0 to 1).
nonisolated struct TrackSample: Hashable, Sendable {
    /// Seconds of the recording.
    var time: TimeInterval
    var box: NormalizedBox
    var confidence: Double
}
