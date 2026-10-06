//
//  UniverseReviewRow.swift
//  Cue Studio
//

import Foundation

/// What the "Your {year} in review" row says and whether it can be played (9.2).
nonisolated struct UniverseReviewRow: Equatable, Sendable {
    /// The story is not there yet: the row is dimmed, has no ▶ Play and a tap only says why.
    let isLocked: Bool
    let title: String
    /// The mono line under the title.
    let line: String
    /// The count on the mini story card.
    let count: Int
    let year: Int
}
