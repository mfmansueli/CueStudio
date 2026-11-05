//
//  ReferralJoinOutcome.swift
//  Cue Studio
//

import Foundation

/// What became of a code a friend typed (the server's answer, or the app's when it couldn't ask).
nonisolated enum ReferralJoinOutcome: String, Codable, Equatable, Sendable {
    /// The code counts: the friend's first export will reward the creator who shared it.
    case joined
    /// No creator has this code.
    case unknown
    /// The creator's own code.
    case own
    /// This iPhone already joined with a code.
    case already
    /// Cue's server couldn't be reached.
    case offline
}
