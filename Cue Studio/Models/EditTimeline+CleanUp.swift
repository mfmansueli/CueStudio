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

    /// Every place the suggestions play in the edit (edited seconds): a moment of a copied clip plays twice, and removing it
    /// takes it out of both (`remove`), so both count. In play order; overlapping ones are not joined.
    func editedSpans(ofEvery suggestions: [CleanUpSuggestion]) -> [TimeSpan] {
        var result: [TimeSpan] = []
        var elapsed: TimeInterval = 0
        for segment in segments {
            defer { elapsed += segment.duration }
            for suggestion in suggestions where suggestion.sourceID == segment.sourceID {
                let from = max(segment.sourceStart, suggestion.span.start), until = min(segment.sourceEnd, suggestion.span.end)
                guard until - from > 0.000_1 else { continue }
                result.append(TimeSpan(
                    start: elapsed + segment.editedOffset(forSource: from - segment.sourceStart),
                    end: elapsed + segment.editedOffset(forSource: until - segment.sourceStart)
                ))
            }
        }
        return result
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
