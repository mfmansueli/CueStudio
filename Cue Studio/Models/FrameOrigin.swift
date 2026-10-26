//
//  FrameOrigin.swift
//  Cue Studio
//

import Foundation

/// Where a frozen frame came from (Freeze frame): which recording (nil: the take) and which second of it, so what covers that
/// moment (a Blur area) covers the still too.
nonisolated struct FrameOrigin: Codable, Hashable, Sendable {
    var sourceID: UUID?
    /// Seconds of that recording.
    var time: TimeInterval
}
