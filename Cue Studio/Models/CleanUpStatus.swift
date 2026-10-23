//
//  CleanUpStatus.swift
//  Cue Studio
//

import Foundation

/// What the creator decided about a Clean Up suggestion.
nonisolated enum CleanUpStatus: String, LenientChoice, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CleanUpStatus.pending

    /// Not reviewed yet.
    case pending
    /// Stays in the video; "Remove all" leaves it alone.
    case kept
    /// Cut from the timeline (undo brings it back).
    case removed
}
