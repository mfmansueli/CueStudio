//
//  QuickEditViewModel+Pauses.swift
//  Cue Studio
//

import Foundation

/// Remove Pauses: the quick way to Clean Up's pauses. It listens to the take (the same analysis,
/// on the device), says how many pauses longer than the threshold it found and how much they add
/// up to, plays the result without them (Preview) and takes them out in one undo step (Apply).
/// Filler words and retakes stay in Clean Up, where each is reviewed.
extension QuickEditViewModel {
    /// Pauses Apply would take out: still to review, still playing, at least as long as the
    /// threshold ("Ignore pauses under").
    var removablePauses: [CleanUpSuggestion] {
        pendingSuggestions.filter { $0.kind == .pause }
    }

    /// The pauses Pauses lists and marks on the timeline: still playing, at least as long as the
    /// threshold, to remove or kept.
    var pauseCandidates: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.kind == .pause && $0.status != .removed && !edit.timeline.isRemoved($0.span) }
    }

    /// The pauses the preview took out (none when it isn't playing).
    var previewedPauses: [CleanUpSuggestion] {
        guard let base = pausePreviewBase else { return [] }
        let before = Set(base.suggestions.filter { $0.status == .pending }.map(\.id))
        return edit.suggestions.filter { $0.kind == .pause && $0.status == .removed && before.contains($0.id) }
    }

    var isPreviewingPauses: Bool { pausePreviewBase != nil }

    /// The pauses the tool is about: the ones the preview took out while it plays, else the ones
    /// Apply would take.
    var shownPauses: [CleanUpSuggestion] {
        isPreviewingPauses ? previewedPauses : removablePauses
    }

    /// "Found 3 pauses", "Found 1 pause" or "No long pauses".
    var pausesTitle: String {
        switch shownPauses.count {
        case 0: String(localized: "No long pauses")
        case 1: String(localized: "Found 1 pause")
        default: String(localized: "Found \(shownPauses.count) pauses")
        }
    }

    /// "Total: 2.8s"
    var pausesTotalLabel: String {
        let total = shownPauses.reduce(0) { $0 + $1.span.duration }
        return String(localized: "Total: \(total.formatted(.number.precision(.fractionLength(1)).locale(.interface)))s")
    }

    /// Plays the edit from the start without the pauses. Nothing is kept until Apply.
    func previewPauses() {
        guard isReady, pausePreviewBase == nil else { return }
        let pauses = removablePauses
        guard !pauses.isEmpty else { return }
        endChange()
        var timeline = edit.timeline
        guard timeline.remove(pauses.map(\.span)) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        pausePreviewBase = snapshot
        var previewed = edit
        previewed.timeline = timeline
        previewed.suggestions = marking(Set(pauses.map(\.id)), as: .removed)
        edit = previewed
        player.seek(to: 0)
        player.play()
    }

    /// Takes the pauses out: what the preview plays, or (without a preview) the pauses found. One
    /// undo step.
    func applyPauses() {
        guard isReady else { return }
        if let base = pausePreviewBase {
            let count = previewedPauses.count
            let total = previewedPauses.reduce(0) { $0 + $1.span.duration }
            pausePreviewBase = nil
            recordUndoStep(base)
            toast.show(removedPausesMessage(count: count, total: total))
            return
        }
        let pauses = removablePauses
        guard !pauses.isEmpty else { return }
        var timeline = edit.timeline
        guard timeline.remove(pauses.map(\.span)) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        commit(timeline, suggestions: marking(Set(pauses.map(\.id)), as: .removed))
        toast.show(removedPausesMessage(count: pauses.count, total: pauses.reduce(0) { $0 + $1.span.duration }))
    }

    /// Puts the pauses back after a preview, as if it never played.
    func cancelPausePreview() {
        guard let base = pausePreviewBase else { return }
        pausePreviewBase = nil
        player.pause()
        restore(base)
    }

    private func marking(_ ids: Set<UUID>, as status: CleanUpStatus) -> [CleanUpSuggestion] {
        edit.suggestions.map { suggestion in
            var decided = suggestion
            if ids.contains(suggestion.id) { decided.status = status }
            return decided
        }
    }

    private func removedPausesMessage(count: Int, total: TimeInterval) -> String {
        let seconds = total.formatted(.number.precision(.fractionLength(1)).locale(.interface))
        return count == 1
            ? String(localized: "Removed 1 pause · \(seconds)s")
            : String(localized: "Removed \(count) pauses · \(seconds)s")
    }
}
