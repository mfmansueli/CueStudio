//
//  TimeSpan.swift
//  Cue Studio
//

import Foundation

/// A stretch of the original recording, in seconds.
nonisolated struct TimeSpan: Codable, Hashable, Sendable {
    var start: TimeInterval
    var end: TimeInterval

    var duration: TimeInterval { max(0, end - start) }

    func contains(_ time: TimeInterval) -> Bool { time >= start && time < end }
}
