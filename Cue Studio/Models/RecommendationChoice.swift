//
//  RecommendationChoice.swift
//  Cue Studio
//

import Foundation

/// What the creator answered to a platform recommendation, for this recording session.
nonisolated enum RecommendationChoice: Hashable, Sendable {
    /// Not answered yet: the Creator Setup stays in use while the card asks.
    case undecided
    case useRecommended
    case keepCreatorSetup
}
