//
//  QuickEditViewModel+PausesPanel.swift
//  Cue Studio
//

import Foundation

/// Pauses (the old Clean Up): the pauses longer than the threshold, marked on the video track in
/// yellow (to go) or gray (to keep); tap one to switch it, Listen to hear it (without it when it's
/// marked); filler words and possible retakes below, the same way. "Remove N" takes every marked
/// one out in one undo step and keeps the rest; the time saved shows first. The pauses come from
/// the take's loudness and the words from its transcript (`CleanUpAnalyzer`), each cut keeping a
/// short breath on both sides (`SilenceDetector.padding`).
extension QuickEditViewModel {
    /// Played around a pause when listening to it.
    static let listenMargin: TimeInterval = 1.2

    /// Filler words and possible retakes still playing, to remove or kept.
    var wordCandidates: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.kind != .pause && $0.status != .removed && !edit.timeline.isRemoved($0.span) }
    }

    /// Whether a suggestion is marked to go: pauses by default, words when Clean Up is sure.
    func isMarked(_ suggestion: CleanUpSuggestion) -> Bool {
        if let mark = cleanUpMarks[suggestion.id] { return mark }
        guard suggestion.status == .pending else { return false }
        return suggestion.kind == .pause || suggestion.isSure
    }

    func toggleMark(_ id: UUID) {
        guard let suggestion = edit.suggestions.first(where: { $0.id == id }) else { return }
        Haptics.selection()
        cleanUpMarks[id] = !isMarked(suggestion)
    }

    /// A card tapped: switches its mark and shows that moment.
    func tapCleanUpCard(_ id: UUID) {
        toggleMark(id)
        guard let suggestion = edit.suggestions.first(where: { $0.id == id }),
              let start = edit.timeline.editedSpan(forSource: suggestion.span)?.start else { return }
        player.pause()
        player.seek(to: max(0, start - 0.4))
    }

    /// Everything marked to go.
    var markedCleanUp: [CleanUpSuggestion] {
        (pauseCandidates + wordCandidates).filter(isMarked)
    }

    /// Seconds of the edit the marked ones would take out.
    var cleanUpSaving: TimeInterval {
        markedCleanUp.reduce(0) { total, suggestion in
            total + (edit.timeline.editedSpan(forSource: suggestion.span)?.duration ?? 0)
        }
    }

    /// "−4.1s"
    var cleanUpSavingLabel: String {
        "−" + DurationText.tenths(cleanUpSaving)
    }

    /// "00:21.6 → 00:17.5"
    var cleanUpResultLabel: String {
        DurationText.editor(edit.editedDuration) + " → " + DurationText.editor(max(0, edit.editedDuration - cleanUpSaving))
    }

    /// "Remove 3 pauses", "Remove 1 pause", "Remove 4" with words in it, or "Nothing selected".
    var cleanUpApplyLabel: String {
        let marked = markedCleanUp
        guard !marked.isEmpty else { return String(localized: "Nothing selected") }
        if marked.allSatisfy({ $0.kind == .pause }) {
            return marked.count == 1 ? String(localized: "Remove 1 pause") : String(localized: "Remove \(marked.count) pauses")
        }
        return String(localized: "Remove \(marked.count)")
    }

    /// Takes every marked pause and word out (one undo step) and keeps the others listed.
    func applyCleanUp() {
        guard isReady else { return }
        let marked = markedCleanUp
        guard !marked.isEmpty else { return }
        let saving = cleanUpSaving
        let kept = Set((pauseCandidates + wordCandidates).filter { !isMarked($0) }.map(\.id))
        let removed = Set(marked.map(\.id))
        var timeline = edit.timeline
        guard timeline.remove(marked.map(\.span)) else {
            toast.show(String(localized: "A video needs at least one clip"))
            return
        }
        let decided = edit.suggestions.map { suggestion in
            var decided = suggestion
            if removed.contains(suggestion.id) { decided.status = .removed }
            if kept.contains(suggestion.id) { decided.status = .kept }
            return decided
        }
        player.pause()
        commit(timeline, suggestions: decided)
        cleanUpMarks = [:]
        panel = nil
        let seconds = DurationText.tenths(saving)
        let pauses = marked.filter { $0.kind == .pause }.count
        toast.show(pauses == marked.count
            ? (pauses == 1 ? String(localized: "Removed 1 pause · \(seconds) shorter") : String(localized: "Removed \(pauses) pauses · \(seconds) shorter"))
            : String(localized: "Removed \(marked.count) · \(seconds) shorter"))
    }

    /// Listen: 1.2 s before to 1.2 s after; a marked one is skipped, so what plays is the result.
    func listen(to id: UUID) {
        guard isReady, let suggestion = edit.suggestions.first(where: { $0.id == id }),
              let span = edit.timeline.editedSpan(forSource: suggestion.span) else { return }
        let total = edit.editedDuration
        let before = max(0, span.start - Self.listenMargin)...span.start
        let after = span.end...min(total, span.end + Self.listenMargin)
        let back = max(0, span.start - 0.3)
        listeningID = id
        toast.show(isMarked(suggestion) ? String(localized: "Hearing it without this pause") : String(localized: "Hearing the pause as it is"))
        previewTask?.cancel()
        let parts = isMarked(suggestion) ? [before, after] : [before.lowerBound...after.upperBound]
        previewTask = Task { [weak self] in
            for part in parts {
                guard let self, !Task.isCancelled else { return }
                player.pause()
                player.reviewedPart = part
                player.seek(to: part.lowerBound)
                player.play()
                try? await Task.sleep(for: .seconds(part.upperBound - part.lowerBound + 0.15))
            }
            guard let self, !Task.isCancelled else { return }
            player.pause()
            player.reviewedPart = nil
            player.seek(to: back)
            listeningID = nil
        }
    }

    /// "1.2s" for a card: the silence's whole length for a pause, the word's for a word.
    func cardLength(_ suggestion: CleanUpSuggestion) -> String {
        let length = suggestion.kind == .pause ? SilenceDetector.silenceLength(ofCut: suggestion.span) : suggestion.span.duration
        return DurationText.tenths(length)
    }

    /// Where a card's moment is in the edit: "00:04.1".
    func cardTime(_ suggestion: CleanUpSuggestion) -> String {
        DurationText.editor(edit.timeline.editedSpan(forSource: suggestion.span)?.start ?? 0)
    }
}
