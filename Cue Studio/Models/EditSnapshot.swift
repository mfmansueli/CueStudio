//
//  EditSnapshot.swift
//  Cue Studio
//

import Foundation

/// One undo step of Quick edit: the timeline and what was decided about Clean Up's suggestions,
/// so undoing a "Remove" brings back both the piece and the suggestion to review.
nonisolated struct EditSnapshot: Codable, Hashable, Sendable {
    var timeline: EditTimeline
    var suggestions: [CleanUpSuggestion]
}
