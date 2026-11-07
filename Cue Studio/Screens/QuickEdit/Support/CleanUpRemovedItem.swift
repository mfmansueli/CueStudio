//
//  CleanUpRemovedItem.swift
//  Cue Studio
//

import Foundation

/// A row of Clean up's "Removed" list: one removed pause, filler or repeat at one place it can come back (a copied clip gives
/// two rows), or, when it has no place, the suggestion with why (`EditTimeline.PutBackBlock`).
struct CleanUpRemovedItem: Identifiable, Hashable {
    let suggestion: CleanUpSuggestion
    /// What was taken out, in seconds of its recording.
    let span: TimeSpan
    /// Where it comes back; nil when it can't.
    let place: EditTimeline.PutBackPlace?
    let block: EditTimeline.PutBackBlock?

    var id: String {
        place.map { "\(suggestion.id.uuidString)-\($0.segmentID.uuidString)" } ?? suggestion.id.uuidString
    }
}
