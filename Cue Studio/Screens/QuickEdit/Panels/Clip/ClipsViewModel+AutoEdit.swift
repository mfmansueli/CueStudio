//
//  ClipsViewModel+AutoEdit.swift
//  Cue Studio
//

import Foundation

/// Auto edit's speech step turned off: what it took out comes back, every one at its place, as one change; the creator's own
/// removals and every other edit stay (`EditTimeline.putBack`, as Clean up's Put back).
extension ClipsViewModel {
    /// Puts back the removed suggestions `ids` wherever they can come back, in one change; how many came back.
    @discardableResult
    func putBackAll(_ ids: Set<UUID>) -> Int {
        guard isReady else { return 0 }
        var timeline = edit.timeline
        var suggestions = edit.suggestions
        var count = 0
        // One at a time, each placed on the timeline the last one left, so later places stay right (a copied clip: a place each).
        while count < ids.count * 4, let item = Self.removedItem(in: timeline, suggestions: suggestions, among: ids), let place = item.place {
            guard timeline.putBack(item.span, in: item.suggestion.sourceID, at: place) else { break }
            count += 1
            if timeline.putBackPlaces(for: item.span, in: item.suggestion.sourceID).isEmpty,
               let index = suggestions.firstIndex(where: { $0.id == item.suggestion.id }) {
                suggestions[index].status = .kept
                suggestions[index].removedSpan = nil
            }
        }
        guard count > 0 else { return 0 }
        player.pause()
        commit(timeline, suggestions: suggestions)
        return count
    }

    /// The first of `ids` still removed with a place to come back to.
    private static func removedItem(in timeline: EditTimeline, suggestions: [CleanUpSuggestion], among ids: Set<UUID>) -> CleanUpRemovedItem? {
        for suggestion in suggestions where suggestion.status == .removed && ids.contains(suggestion.id) {
            let span = suggestion.removedSpan ?? suggestion.span
            if let place = timeline.putBackPlaces(for: span, in: suggestion.sourceID).first {
                return CleanUpRemovedItem(suggestion: suggestion, span: span, place: place, block: nil)
            }
        }
        return nil
    }
}
