//
//  ClipReversal.swift
//  Cue Studio
//

import Foundation

/// A recording of a montage that is another one played backwards (Reverse): which recording (nil: the take) and which stretch
/// of it, so reversing the clip again puts the original back.
nonisolated struct ClipReversal: Codable, Hashable, Sendable {
    /// The recording reversed; nil for the take itself.
    var sourceID: UUID?
    /// The stretch of it reversed, in its seconds.
    var span: TimeSpan

    /// The stretch of the original that `reversed` (seconds of the reversed file) shows.
    func original(of reversed: TimeSpan) -> TimeSpan {
        TimeSpan(start: max(span.start, span.end - reversed.end), end: min(span.end, span.end - reversed.start))
    }
}
