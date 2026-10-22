//
//  WatchScreen.swift
//  Cue Studio
//

import Foundation

/// What the watch shows (v31 board "Todos os estados"). Only `WatchScreenRule` makes one, from the iPhone's last answer.
nonisolated enum WatchScreen: Hashable, Sendable {
    /// Waiting for the iPhone's first answer: never an old state.
    case checking
    case noSession
    case ready
    /// Record was asked; nothing records until the iPhone says so.
    case requesting
    case countdown(remaining: Int)
    case recording
    /// End was asked during a take.
    case stopping
    case saving
    case saved(take: Int, seconds: Double)
    case rehearsal
    /// A rehearsal command waits for its answer.
    case sending
    /// The iPhone can't be reached: the last state it sent, if any, is shown as old.
    case lost
    /// A command had no answer in time.
    case noResponse
    case failedStart
    case failedSave
    case unavailable
}
