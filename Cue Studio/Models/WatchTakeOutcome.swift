//
//  WatchTakeOutcome.swift
//  Cue Studio
//

import Foundation

/// How the last take ended, as the Apple Watch shows it until the next command.
nonisolated enum WatchTakeOutcome: Hashable, Sendable {
    case saved(take: Int, seconds: Double)
    /// The camera didn't start the take (or wasn't ready).
    case failedStart
    /// The take ended but couldn't be saved.
    case failedSave
}
