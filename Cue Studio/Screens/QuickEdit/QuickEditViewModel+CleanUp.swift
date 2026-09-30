//
//  QuickEditViewModel+CleanUp.swift
//  Cue Studio
//

import Foundation

/// Clean Up: pauses, filler words and possible retakes found in the take, as suggestions the creator
/// reviews one by one (Keep or Remove) or removes together when Clean Up is sure. Every decision is
/// an undo step.
extension QuickEditViewModel {
    static let defaultPauseThreshold: TimeInterval = 0.7
    static let pauseThresholdRange: ClosedRange<TimeInterval> = 0.3...2

    // MARK: - Analysis

    /// Listens to the take the first time Clean Up opens: loudness for pauses, the transcript (in
    /// the Voice Following language, or the script's) for filler words and retakes. Nothing is
    /// removed.
    func analyzeIfNeeded() async {
        guard isReady, analysis != .running else { return }
        guard !edit.cleanUpAnalyzed else {
            analysis = .done
            return
        }
        analysis = .running
        let found: [CleanUpSuggestion]
        do {
            found = try await editing.cleanUpSuggestions(forVideoAt: videoURL, language: speechLanguage)
        } catch {
            guard !isClosed else { return }
            analysis = .failed
            toast.show(String(localized: "Couldn't listen to this take"))
            return
        }
        guard !isClosed else { return }
        var analyzed = edit
        analyzed.suggestions = CleanUpAnalyzer.merged(found, into: edit.suggestions)
        analyzed.cleanUpAnalyzed = true
        edit = analyzed
        analysis = .done
    }

    // MARK: - Reading

    /// What Clean Up lists: suggestions between the handles, in the order they're heard, without
    /// the pauses under "Ignore pauses under".
    var cleanUpSuggestions: [CleanUpSuggestion] {
        let timeline = edit.timeline
        return edit.suggestions
            .filter { $0.span.start >= timeline.trimStart - 0.001 && $0.span.end <= timeline.trimEnd + 0.001 }
            .filter { $0.kind != .pause || SilenceDetector.silenceLength(ofCut: $0.span) >= pauseThreshold - 0.001 }
            .sorted { $0.span.start < $1.span.start }
    }

    /// Still to review: not decided, and still playing (a cut by hand may have taken it already).
    var pendingSuggestions: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.status == .pending && !edit.timeline.isRemoved($0.span) }
    }

    /// What "Remove all" takes: the pending suggestions Clean Up is sure about.
    var sureSuggestions: [CleanUpSuggestion] {
        pendingSuggestions.filter(\.isSure)
    }

    /// Pauses under the threshold, left out of the list.
    var ignoredPauseCount: Int {
        let timeline = edit.timeline
        return edit.suggestions.filter {
            $0.kind == .pause && $0.span.start >= timeline.trimStart && $0.span.end <= timeline.trimEnd
                && SilenceDetector.silenceLength(ofCut: $0.span) < pauseThreshold - 0.001
        }.count
    }

    /// "3 to review" or "All clean".
    var reviewTitle: String {
        let count = pendingSuggestions.count
        return count == 0 ? String(localized: "All clean") : String(localized: "\(count) to review")
    }

    var reviewSubtitle: String {
        pendingSuggestions.isEmpty
            ? String(localized: "Every suggestion reviewed")
            : String(localized: "Suggestions only — you decide what goes")
    }

    /// "Remove all · 4", or "Done" when nothing sure is left.
    var removeAllLabel: String {
        let count = sureSuggestions.count
        return count == 0 ? String(localized: "Done") : String(localized: "Remove all · \(count)")
    }

    /// "0.7s"
    var pauseThresholdLabel: String {
        pauseThreshold.formatted(.number.precision(.fractionLength(1)).locale(.interface)) + "s"
    }

    /// "2 short pauses kept" or "natural pauses stay".
    var ignoredPausesLabel: String {
        let count = ignoredPauseCount
        switch count {
        case 0: return String(localized: "natural pauses stay")
        case 1: return String(localized: "1 short pause kept")
        default: return String(localized: "\(count) short pauses kept")
        }
    }

    /// "00:04.20 · 0.9s · May be intentional — for emphasis"
    func detail(for suggestion: CleanUpSuggestion) -> String {
        let length = suggestion.kind == .pause ? SilenceDetector.silenceLength(ofCut: suggestion.span) : suggestion.span.duration
        let parts = [
            DurationText.timecode(suggestion.span.start, total: edit.sourceDuration),
            length.formatted(.number.precision(.fractionLength(1)).locale(.interface)) + "s",
            suggestion.note,
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// Where a suggestion sits on the edited timeline; nil once it no longer plays.
    func editedStart(of suggestion: CleanUpSuggestion) -> TimeInterval? {
        guard suggestion.status != .removed, !edit.timeline.isRemoved(suggestion.span) else { return nil }
        return edit.timeline.editedTime(following: suggestion.span.start)
    }

    // MARK: - Decisions

    /// Tapping a suggestion: the playhead goes to it (paused), to listen before deciding.
    func seek(toSuggestion id: UUID) {
        guard isReady, let suggestion = suggestion(id) else { return }
        guard let time = editedStart(of: suggestion) else {
            toast.show(String(localized: "Already removed"))
            return
        }
        player.pause()
        player.seek(to: time)
    }

    /// Cuts a suggestion out of the edit, like any cut (undo brings it back).
    func removeSuggestion(_ id: UUID) {
        guard isReady, let suggestion = suggestion(id) else { return }
        var timeline = edit.timeline
        if !timeline.isRemoved(suggestion.span) {
            guard timeline.remove([suggestion.span]) else {
                toast.show(String(localized: "Keep at least one section"))
                return
            }
        }
        commit(timeline, suggestions: deciding([id], .removed))
        toast.show(removedMessage(for: suggestion))
    }

    /// Keeps a suggestion: it stays in the video, and "Remove all" leaves it alone.
    func keepSuggestion(_ id: UUID) {
        guard isReady, suggestion(id) != nil else { return }
        commit(edit.timeline, suggestions: deciding([id], .kept))
    }

    /// Tapping "Kept" puts it back up for review; "Removed" comes back with Undo.
    func reviewAgain(_ id: UUID) {
        guard isReady, let suggestion = suggestion(id) else { return }
        switch suggestion.status {
        case .kept: commit(edit.timeline, suggestions: deciding([id], .pending))
        case .removed: toast.show(String(localized: "Use Undo to bring it back"))
        case .pending: break
        }
    }

    // MARK: - Review (words)

    /// What Review lists: filler words and possible retakes (the pauses have their own section).
    var wordSuggestions: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.kind != .pause }
    }

    /// Words still to review.
    var pendingWordSuggestions: [CleanUpSuggestion] {
        pendingSuggestions.filter { $0.kind != .pause }
    }

    /// "3 to review" or "All clean", for the words.
    var wordsReviewTitle: String {
        let count = pendingWordSuggestions.count
        return count == 0 ? String(localized: "All clean") : String(localized: "\(count) to review")
    }

    /// "Remove all · 2" for the words Clean Up is sure about, or "Done".
    var removeAllWordsLabel: String {
        let count = pendingWordSuggestions.filter(\.isSure).count
        return count == 0 ? String(localized: "Done") : String(localized: "Remove all · \(count)")
    }

    /// "Remove all" in Review: the words Clean Up is sure about, in one undo step.
    func removeAllSureWords() {
        removeAllSure(pendingWordSuggestions.filter(\.isSure), among: pendingWordSuggestions)
    }

    /// "Remove all": every pending suggestion Clean Up is sure about goes, in one undo step. The
    /// unsure ones stay for the creator to listen to.
    func removeAllSureSuggestions() {
        removeAllSure(sureSuggestions, among: pendingSuggestions)
    }

    /// `pending`: what "left to review" counts.
    private func removeAllSure(_ sure: [CleanUpSuggestion], among pending: [CleanUpSuggestion]) {
        guard isReady else { return }
        guard !sure.isEmpty else { return }
        var timeline = edit.timeline
        guard timeline.remove(sure.map(\.span)) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        let left = pending.count - sure.count
        commit(timeline, suggestions: deciding(Set(sure.map(\.id)), .removed))
        toast.show(left > 0
            ? String(localized: "Removed \(sure.count) · \(left) left to review")
            : String(localized: "Removed \(sure.count)"))
    }

    func lowerPauseThreshold() {
        setPauseThreshold(pauseThreshold - 0.1)
    }

    func raisePauseThreshold() {
        setPauseThreshold(pauseThreshold + 0.1)
    }

    /// Pending suggestions for the Clean Up button in Trim; nil before the take was analyzed.
    var cleanUpBadge: Int? {
        guard analysis == .done else { return nil }
        let count = pendingSuggestions.count
        return count > 0 ? count : nil
    }

    // MARK: - Private

    private func suggestion(_ id: UUID) -> CleanUpSuggestion? {
        edit.suggestions.first { $0.id == id }
    }

    private func deciding(_ ids: Set<UUID>, _ status: CleanUpStatus) -> [CleanUpSuggestion] {
        edit.suggestions.map { suggestion in
            var decided = suggestion
            if ids.contains(suggestion.id) { decided.status = status }
            return decided
        }
    }

    private func setPauseThreshold(_ value: TimeInterval) {
        let tenths = (value * 10).rounded() / 10
        pauseThreshold = min(Self.pauseThresholdRange.upperBound, max(Self.pauseThresholdRange.lowerBound, tenths))
    }

    private func removedMessage(for suggestion: CleanUpSuggestion) -> String {
        switch suggestion.kind {
        case .pause: String(localized: "Pause removed")
        case .filler: String(localized: "\(suggestion.title) removed")
        case .retake: String(localized: "Retake removed")
        }
    }
}
