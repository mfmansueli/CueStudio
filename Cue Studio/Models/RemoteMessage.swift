//
//  RemoteMessage.swift
//  Cue Studio
//

import Foundation

/// What travels between the teleprompter and its remote.
nonisolated enum RemoteMessage: Codable, Hashable, Sendable {
    /// Remote → teleprompter.
    case command(RemoteCommand)
    /// Teleprompter → remote.
    case status(RemoteStatus)
}
