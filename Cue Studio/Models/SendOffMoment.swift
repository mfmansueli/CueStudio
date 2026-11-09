//
//  SendOffMoment.swift
//  Cue Studio
//

import Foundation

/// What a send-off (8.2) tells besides the networks (`FirstCelebration`): the creator's first star, when this is their first confirmed post and
/// the star wasn't told in Takes, and the milestone icon the post opened, offered in a row of the send-off itself (never a screen after it).
nonisolated struct SendOffMoment: Equatable, Sendable {
    /// The first confirmed post, with the first star still untold: the send-off's eyebrow says "FIRST VIDEO · FIRST STAR".
    var isFirstStar = false
    /// The milestone (1, 10, 25, 50 confirmed posts in the creator's life) due now; it counts as told when the send-off ends.
    var milestone: Int?

    /// The icon the milestone opens.
    var icon: AppIconChoice? { milestone.flatMap(AppIconChoice.init(milestone:)) }
}
