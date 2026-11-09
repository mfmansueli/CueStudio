//
//  RecommendationChoice.swift
//  Cue Studio
//

import Foundation

/// What the creator answered to a platform recommendation, for this recording session.
nonisolated enum RecommendationChoice: Hashable, Sendable {
    /// Not answered yet: what is on screen stays in use while the card asks.
    case undecided
    /// "Use Recommended": the listed changes were applied.
    case useRecommended
    /// "Keep as is": nothing changed.
    case keepAsIs
}
