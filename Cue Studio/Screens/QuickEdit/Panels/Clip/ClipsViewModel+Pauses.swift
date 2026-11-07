//
//  ClipsViewModel+Pauses.swift
//  Cue Studio
//

import Accessibility
import Foundation

/// Clean up's marks and its Remove: the pauses longer than the threshold (Pauses) and the filler words and repeats (Words),
/// marked on the video track in yellow (to go) or gray (to keep); tap one to switch it, Listen to hear it (without it when it's
/// marked). "Remove" takes every marked one out in one undo step, with Undo on its toast, and keeps the rest; its label says
/// which kinds it removes, and the time saved counts each second once, however the marks overlap. The pauses come from the
/// take's loudness and the words from its transcript (`CleanUpAnalyzer`); a pause's cut leaves "Gap left" of its silence
/// (`CleanUpSuggestion.cut(leaving:)`), the one rule the list, the marks, Listen and the cut read. Closing the panel with ✓
/// applies nothing: only Remove does.
extension ClipsViewModel {
    /// Played around a pause when listening to it.
    static let listenMargin: TimeInterval = 1.2

    /// "Gap left": how much silence a removed pause leaves. Changing it changes only what is removed next.
    var pauseGap: PauseGap {
        get { edit.pauseGap }
        set { changeEdit(key: "pauseGap") { $0.pauseGap = newValue } }
    }

    /// The pauses Pauses lists and marks on the timeline: still playing, at least as long as the threshold, with something to
    /// take out at the gap left, to remove or kept. The silence the edit opens on is the start row's (`cleanUpStart`), not a card.
    var pauseCandidates: [CleanUpSuggestion] {
        let opening = cleanUpStart != nil ? openingPauseID : nil
        return cleanUpSuggestions.filter { suggestion in
            suggestion.kind == .pause && suggestion.status != .removed && !edit.timeline.isRemoved(suggestion) && suggestion.id != opening
                && removal(of: suggestion) != nil
        }
    }

    /// Filler words and repeats still playing, to remove or kept (Words).
    var wordCandidates: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.kind != .pause && $0.status != .removed && !edit.timeline.isRemoved($0) }
    }

    /// Whether a suggestion is marked to go: pauses heard clearly by default, words when Clean Up is sure, a try at a script line
    /// only once the creator kept another try of it (`keepTry`); a pause heard over background sound or under a soft voice waits
    /// for the creator (`CleanUpSuggestion.isMarkedByDefault`).
    func isMarked(_ suggestion: CleanUpSuggestion) -> Bool {
        if let mark = cleanUpMarks[suggestion.id] { return mark }
        guard suggestion.status == .pending else { return false }
        if let attempt = suggestion.attempt {
            return edit.suggestions.contains { $0.id != suggestion.id && $0.attempt?.group == attempt.group && $0.attempt?.kept == true }
        }
        return suggestion.isMarkedByDefault
    }

    func toggleMark(_ id: UUID) {
        guard let suggestion = edit.suggestions.first(where: { $0.id == id }) else { return }
        Haptics.selection()
        cleanUpMarks[id] = !isMarked(suggestion)
    }

    /// A card tapped: switches its mark, lights it (its mark on the timeline is where the playhead goes) and shows that moment.
    /// VoiceOver hears what it is now.
    func tapCleanUpCard(_ id: UUID) {
        toggleMark(id)
        guard let suggestion = edit.suggestions.first(where: { $0.id == id }) else { return }
        highlightedCleanUpID = id
        AccessibilityNotification.Announcement(isMarked(suggestion) ? String(localized: "Remove") : String(localized: "Keep")).post()
        show(suggestion)
    }

    /// A mark tapped on the timeline (owner, canvas 2 M3): the first tap goes to its card (its tab, scrolled into view, lit) and
    /// shows that moment, changing nothing; a tap on the mark of the lit card switches it, as a tap on the card does. Nothing
    /// changes what goes without the card in sight.
    func revealCleanUpMark(_ id: UUID) {
        guard let suggestion = edit.suggestions.first(where: { $0.id == id }) else { return }
        guard highlightedCleanUpID != id else {
            tapCleanUpCard(id)
            return
        }
        let tab: EditorPanelTab = suggestion.kind == .pause ? .pauses : .words
        if cleanUpTab != tab { showCleanUpTab(tab) } else { Haptics.selection() }
        highlightedCleanUpID = id
        show(suggestion)
    }

    /// Pauses and shows the moment just before `suggestion`.
    private func show(_ suggestion: CleanUpSuggestion) {
        guard let start = editedCut(of: suggestion)?.start else { return }
        player.pause()
        player.seek(to: max(0, start - 0.4))
    }

    /// Everything marked to go.
    var markedCleanUp: [CleanUpSuggestion] {
        (pauseCandidates + wordCandidates).filter(isMarked)
    }

    /// The suggestion as removing it now takes it out: a pause with the gap left (`CleanUpSuggestion.removal(leaving:)`).
    func removal(of suggestion: CleanUpSuggestion) -> CleanUpSuggestion? {
        suggestion.removal(leaving: pauseGap, recordingLength: edit.timeline.duration(ofSource: suggestion.sourceID))
    }

    /// Where removing the suggestion would cut, in the edit (its first place); nil once nothing of it plays.
    func editedCut(of suggestion: CleanUpSuggestion) -> TimeSpan? {
        removal(of: suggestion).flatMap { edit.timeline.editedSpan(of: $0) } ?? edit.timeline.editedSpan(of: suggestion)
    }

    /// Seconds of the edit the marked ones would take out: every place they play (a copied clip twice), each second once.
    var cleanUpSaving: TimeInterval {
        let cuts = markedCleanUp.compactMap(removal)
        return TimeSpan.merged(edit.timeline.editedSpans(ofEvery: cuts)).reduce(0) { $0 + $1.duration }
    }

    /// "−4.1s"
    var cleanUpSavingLabel: String {
        "−" + DurationText.tenths(cleanUpSaving)
    }

    /// "00:21.6 → 00:17.5" (the arrow follows the reading: "←" in Arabic).
    var cleanUpResultLabel: String {
        let before = DurationText.editor(edit.editedDuration)
        let after = DurationText.editor(max(0, edit.editedDuration - cleanUpSaving))
        return String(localized: "\(before) → \(after)", comment: "Two moments of the video, from → to: a caption line's start and end, the length before and after Clean Up")
    }

    /// What Remove takes out, by kind: "Remove 3 pauses", or the kinds it holds ("Remove pauses and hesitations"), or
    /// "Nothing selected".
    var cleanUpApplyLabel: String {
        let marked = markedCleanUp
        guard !marked.isEmpty else { return String(localized: "Nothing selected") }
        let pauses = marked.contains { $0.kind == .pause }
        let fillers = marked.contains { $0.kind == .filler }
        let repeats = marked.contains { $0.kind == .retake }
        switch (pauses, fillers, repeats) {
        case (true, false, false): return String(localized: "Remove \(marked.count) pauses")
        case (false, true, false): return String(localized: "Remove hesitations", comment: "Clean up: the button takes out the marked ums and uhs")
        case (false, false, true): return String(localized: "Remove repeats", comment: "Clean up: the button takes out the marked repeated tries")
        case (false, true, true): return String(localized: "Remove hesitations and repeats")
        case (true, true, false): return String(localized: "Remove pauses and hesitations")
        case (true, false, true): return String(localized: "Remove pauses and repeats")
        default: return String(localized: "Remove pauses, hesitations and repeats")
        }
    }

    /// Takes every marked pause and word out (one undo step, with Undo on the toast) and keeps the others listed. What each
    /// took out is kept on it (`removedSpan`), for Put back.
    func applyCleanUp() {
        guard isReady else { return }
        let marked = markedCleanUp
        let removals = marked.compactMap(removal)
        guard !removals.isEmpty else { return }
        let saving = cleanUpSaving
        let kept = Set((pauseCandidates + wordCandidates).filter { !isMarked($0) }.map(\.id))
        let cuts = Dictionary(removals.map { ($0.id, $0.span) }, uniquingKeysWith: { first, _ in first })
        var timeline = edit.timeline
        guard timeline.remove(removals) else {
            toast.show(String(localized: "Keep at least one clip"), kind: .problem)
            return
        }
        let decided = edit.suggestions.map { suggestion in
            var decided = suggestion
            if let cut = cuts[suggestion.id] {
                decided.status = .removed
                decided.removedSpan = cut
            }
            if kept.contains(suggestion.id) { decided.status = .kept }
            return decided
        }
        player.pause()
        commit(timeline, suggestions: decided)
        cleanUpMarks = [:]
        panel = nil
        let seconds = DurationText.tenths(saving)
        let pauses = removals.filter { $0.kind == .pause }.count
        toast.show(
            pauses == removals.count
                ? String(localized: "Removed \(pauses) pauses · \(seconds)")
                : String(localized: "Speech cleaned up · \(seconds)", comment: "Toast after Clean up removed pauses, ums and repeats; the time saved"),
            kind: .cue, action: undoAction
        )
    }

    /// Listen: 1.2 s before to 1.2 s after; a marked one is skipped (as it would be cut, with the gap left), so what plays is
    /// the result.
    func listen(to id: UUID) {
        guard isReady, let suggestion = edit.suggestions.first(where: { $0.id == id }), let span = editedCut(of: suggestion) else { return }
        let total = edit.editedDuration
        let before = max(0, span.start - Self.listenMargin)...span.start
        let after = span.end...min(total, span.end + Self.listenMargin)
        let back = max(0, span.start - 0.3)
        listeningID = id
        toast.show(isMarked(suggestion) ? String(localized: "Playing without this pause") : String(localized: "Hearing the pause as it is"))
        play(isMarked(suggestion) ? [before, after] : [before.lowerBound...after.upperBound], back: back)
    }

    /// Plays `parts` (edited seconds) one after the other, then the playhead goes to `back`; Listen's speaker shows meanwhile.
    func play(_ parts: [ClosedRange<TimeInterval>], back: TimeInterval) {
        jobs.start(.preview) { [weak self] _ in
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
        let length = suggestion.kind == .pause ? SilenceDetector.silenceLength(of: suggestion) : suggestion.span.duration
        return DurationText.tenths(length)
    }

    /// Where a card's moment is in the edit: "00:04.1", or "Take 2 · 00:04.1" in a montage.
    func cardTime(_ suggestion: CleanUpSuggestion) -> String {
        let time = DurationText.editor(editedCut(of: suggestion)?.start ?? 0)
        return recordingLabel(of: suggestion).map { "\($0) · \(time)" } ?? time
    }
}
