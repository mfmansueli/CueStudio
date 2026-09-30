//
//  AudioLevelSample.swift
//  Cue Studio
//

import Foundation

/// The microphone level of one buffer, as it arrived.
nonisolated struct AudioLevelSample: Equatable, Sendable {
    /// Average power in dBFS (-160...0).
    let level: Float
    /// `ProcessInfo.systemUptime` when the buffer reached the app: the earliest anything could
    /// react to it.
    let time: TimeInterval
    /// Seconds of audio in the buffer.
    let duration: TimeInterval
}
