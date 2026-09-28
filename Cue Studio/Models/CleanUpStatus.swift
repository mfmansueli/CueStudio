//
//  CleanUpStatus.swift
//  Cue Studio
//

import Foundation

/// What the creator decided about a Clean Up suggestion.
nonisolated enum CleanUpStatus: String, Codable, Sendable {
    /// Not reviewed yet.
    case pending
    /// Stays in the video; "Remove all" leaves it alone.
    case kept
    /// Cut from the timeline (undo brings it back).
    case removed
}
