//
//  WatchPhoneState.swift
//  Cue Studio
//

import Foundation

/// What the iPhone tells the watch, every time something changes and in answer to each command.
nonisolated struct WatchPhoneState: Codable, Hashable, Sendable {
    var phase: WatchPhase
    /// Nil for a freestyle recording.
    var scriptTitle: String?
    /// Voice Following sets the pace; speed doesn't apply.
    var followsVoice = false
    /// Times the natural reading pace (1.2 is "1.2×"), as the iPhone's speed shows it.
    var speedMultiple = 1.0
    var isPlaying = false
    /// When the take started, so the watch counts its time without a message a second.
    var recordingStartedAt: Date?
    /// The last command whose effect this state shows (or why it couldn't happen): the watch stops waiting for it.
    var answering: UUID?
    var sentAt = Date()

    static let noSession = WatchPhoneState(phase: .noSession)
}
