//
//  WatchPhase.swift
//  Cue Studio
//

import Foundation

/// Where the iPhone's recorder is, as the watch shows it.
nonisolated enum WatchPhase: Codable, Hashable, Sendable {
    /// The recorder isn't open on the iPhone.
    case noSession
    /// Open, but this session can't record from the watch (Studio's teleprompter, the first flight's practice).
    case unavailable
    /// Ready to record, with a script or freestyle.
    case ready
    /// Counting down; nothing records yet.
    case countdown(remaining: Int)
    case recording
    /// The take ended and the iPhone is saving it.
    case saving
    /// Saved in the iPhone's library: its number and length.
    case saved(take: Int, seconds: Double)
    /// The script plays without recording.
    case rehearsal
    /// The camera didn't start the take.
    case failedStart
    /// The take ended but the iPhone couldn't save it.
    case failedSave
}
