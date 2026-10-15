//
//  EditTimeline+CleanUp.swift
//  Cue Studio
//

import Foundation

/// Clean Up's suggestions on the timeline: each is a moment of its own recording (the take or another recording of the
/// montage), so it is found, shown and taken out there, never in another recording at the same second.
nonisolated extension EditTimeline {
    /// Where the suggestion plays in the edit; nil once nothing of it does.
    func editedSpan(of suggestion: CleanUpSuggestion) -> TimeSpan? {
        editedSpan(forSource: suggestion.span, in: suggestion.sourceID)
    }

    func isRemoved(_ suggestion: CleanUpSuggestion) -> Bool {
        isRemoved(suggestion.span, in: suggestion.sourceID)
    }

    /// Takes the suggestions out, each from its own recording, in one change. False, and no change, when nothing would be
    /// left or nothing changes.
    @discardableResult
    mutating func remove(_ suggestions: [CleanUpSuggestion]) -> Bool {
        var next = self
        var changed = false
        let bySource = Dictionary(grouping: suggestions, by: \.sourceID)
        for (source, group) in bySource {
            changed = next.remove(group.map(\.span), in: source) || changed
        }
        guard changed else { return false }
        self = next
        return true
    }
}
