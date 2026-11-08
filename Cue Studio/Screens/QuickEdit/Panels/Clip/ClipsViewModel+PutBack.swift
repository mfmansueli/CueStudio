//
//  ClipsViewModel+PutBack.swift
//  Cue Studio
//

import Foundation

/// Clean up's "Removed" lists (D7): every pause (Pauses) and every filler or repeat (Words) that was removed, each at every
/// place it can come back, with Put back. Putting one back brings only it (`EditTimeline.putBack`): the rest of the edit, the
/// layers' places (`CutFollowing`, through the commit) and the undo history stay, and its toast has Undo. A clip moved or sped
/// up since doesn't stop it; with no place left (the clips around it deleted, or trimmed past it) the row says why and what to
/// do instead, and nothing comes back approximately.
extension ClipsViewModel {
    /// Removed pauses, at each place they can come back, in play order.
    var removedPauses: [CleanUpRemovedItem] {
        removedItems { $0.kind == .pause }
    }

    /// Removed fillers and repeats, at each place they can come back.
    var removedWords: [CleanUpRemovedItem] {
        removedItems { $0.kind != .pause }
    }

    /// "Pause · 1.2s", "“um” · 0.3s", "Repeat · 1.9s" for a removed row.
    func removedTitle(_ item: CleanUpRemovedItem) -> String {
        let length = DurationText.tenths(item.span.duration)
        switch item.suggestion.kind {
        case .pause: return String(localized: "Pause · \(length)")
        case .filler: return "\(item.suggestion.title) · \(length)"
        case .retake: return String(localized: "Repeat · \(length)")
        }
    }

    /// Where it comes back ("00:04.1", with the recording in a montage), or why it can't.
    func removedDetail(_ item: CleanUpRemovedItem) -> String {
        if let place = item.place {
            let time = DurationText.editor(place.editedTime)
            return recordingLabel(of: item.suggestion).map { "\($0) · \(time)" } ?? time
        }
        switch item.block {
        case .trimmedOff?: return String(localized: "Can't put back · it's past where the video now starts or ends. Drag that edge to bring it back.")
        default: return String(localized: "Can't put back · the clips around it were deleted. Undo brings them back.")
        }
    }

    /// Put back: the stretch comes back at that place, alone. One undo step, with Undo on the toast.
    func putBack(_ item: CleanUpRemovedItem) {
        guard isReady, let place = item.place else { return }
        var timeline = edit.timeline
        guard timeline.putBack(item.span, in: item.suggestion.sourceID, at: place) else {
            toast.show(String(localized: "Can't put it back here any more"), kind: .problem)
            return
        }
        let gained = DurationText.tenths(max(0, timeline.editedDuration - edit.editedDuration))
        // Back everywhere it can be: kept from now on (listed, not marked). Still out somewhere else (a copy): still removed.
        let stillOut = !timeline.putBackPlaces(for: item.span, in: item.suggestion.sourceID).isEmpty
        let decided = edit.suggestions.map { suggestion in
            guard suggestion.id == item.suggestion.id, !stillOut else { return suggestion }
            var kept = suggestion
            kept.status = .kept
            kept.removedSpan = nil
            return kept
        }
        player.pause()
        commit(timeline, suggestions: decided)
        player.seek(to: max(0, place.editedTime - 0.4))
        Haptics.selection()
        let message = switch item.suggestion.kind {
        case .pause: String(localized: "Pause put back · +\(gained)")
        case .filler: String(localized: "\(item.suggestion.title) put back · +\(gained)")
        case .retake: String(localized: "Repeat put back · +\(gained)")
        }
        toast.show(message, action: undoAction)
    }

    // MARK: - Private

    private func removedItems(_ include: (CleanUpSuggestion) -> Bool) -> [CleanUpRemovedItem] {
        let timeline = edit.timeline
        var items: [CleanUpRemovedItem] = []
        for suggestion in edit.suggestions where suggestion.status == .removed && include(suggestion) {
            let span = suggestion.removedSpan ?? suggestion.span
            let places = timeline.putBackPlaces(for: span, in: suggestion.sourceID)
            if places.isEmpty {
                let block = timeline.putBackBlock(for: span, in: suggestion.sourceID)
                // Back already (a handle dragged over it): nothing to put back.
                guard block != .alreadyPlays else { continue }
                items.append(CleanUpRemovedItem(suggestion: suggestion, span: span, place: nil, block: block))
            } else {
                items += places.map { CleanUpRemovedItem(suggestion: suggestion, span: span, place: $0, block: nil) }
            }
        }
        return items.sorted { ($0.place?.editedTime ?? .infinity) < ($1.place?.editedTime ?? .infinity) }
    }
}
