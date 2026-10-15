//
//  QuickEditViewModel+CleanUp.swift
//  Cue Studio
//

import Foundation

/// Clean Up: pauses, filler words and possible retakes found in the take and, in a montage, in every other recording it
/// plays, as suggestions the creator reviews one by one (Keep or Remove) or removes together when Clean Up is sure. Each
/// suggestion stays with its recording: cuts, a new order, copies and speed move where it plays, never what it is. Every
/// decision is an undo step.
extension QuickEditViewModel {
    static let pauseThresholdRange: ClosedRange<TimeInterval> = 0.3...3

    // MARK: - Analysis

    /// Listens to each recording the edit plays the first time Clean Up opens on it (the take, then a montage's other takes
    /// and videos): loudness for pauses, the transcript (in the Voice Following language, or the script's) for filler words and
    /// retakes. Nothing is removed. A recording that can't be listened to leaves the others' suggestions in.
    func analyzeIfNeeded() async {
        guard isReady, analysis != .running else { return }
        let pending = edit.recordingsToCleanUp
        guard !pending.isEmpty else {
            analysis = .done
            return
        }
        analysis = .running
        let urls = clipSourceURLs
        var found: [CleanUpSuggestion] = []
        var listened: [UUID?] = []
        var failed = false
        for source in pending {
            let file: URL? = if let source { urls[source] } else { videoURL }
            guard let url = file else { continue }
            do {
                let heard = try await editing.cleanUpSuggestions(forVideoAt: url, language: speechLanguage)
                found += heard.map { suggestion in
                    var mine = suggestion
                    mine.sourceID = source
                    return mine
                }
                listened.append(source)
            } catch {
                failed = true
            }
            guard !isClosed else { return }
        }
        var analyzed = edit
        // Only the recordings listened to now get fresh suggestions; the others keep theirs.
        let kept = edit.suggestions.filter { !listened.contains($0.sourceID) }
        analyzed.suggestions = kept + CleanUpAnalyzer.merged(found, into: edit.suggestions.filter { listened.contains($0.sourceID) })
        for source in listened {
            if let source { analyzed.cleanUpAnalyzedSources.append(source) } else { analyzed.cleanUpAnalyzed = true }
        }
        edit = analyzed
        if failed, listened.isEmpty {
            analysis = .failed
            toast.show(String(localized: "Couldn't listen to this take"))
            return
        }
        analysis = .done
        if failed { toast.show(String(localized: "Couldn't listen to every clip")) }
    }

    // MARK: - Reading

    /// What Clean Up lists: suggestions within the part of their recording the edit plays (between the handles, for the
    /// take alone), in the order the edit plays them, without the pauses under "Ignore pauses under".
    var cleanUpSuggestions: [CleanUpSuggestion] {
        let timeline = edit.timeline
        return edit.suggestions
            .filter { suggestion in
                guard let extent = timeline.playedExtent(of: suggestion.sourceID) else { return false }
                return suggestion.span.start >= extent.start - 0.001 && suggestion.span.end <= extent.end + 0.001
            }
            .filter { $0.kind != .pause || SilenceDetector.silenceLength(ofCut: $0.span) >= pauseThreshold - 0.001 }
            .sorted { playOrder($0) < playOrder($1) }
    }

    /// Where a suggestion comes in the edit, for the list's order: where it plays, or where it would (a removed one).
    private func playOrder(_ suggestion: CleanUpSuggestion) -> TimeInterval {
        edit.timeline.editedTime(following: suggestion.span.start, in: suggestion.sourceID)
    }

    /// Which recording a suggestion is in, for its card, once the edit plays more than one: "Take 2".
    func recordingLabel(of suggestion: CleanUpSuggestion) -> String? {
        guard !edit.playedSources.isEmpty else { return nil }
        guard let id = suggestion.sourceID else { return String(localized: "This take") }
        return edit.sources.first { $0.id == id }?.title ?? String(localized: "Video")
    }

    /// Still to review: not decided, and still playing (a cut by hand may have taken it already).
    var pendingSuggestions: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.status == .pending && !edit.timeline.isRemoved($0) }
    }

    /// What "Remove all" takes: the pending suggestions Clean Up is sure about.
    var sureSuggestions: [CleanUpSuggestion] {
        pendingSuggestions.filter(\.isSure)
    }

    /// Pauses under the threshold, left out of the list.
    var ignoredPauseCount: Int {
        let timeline = edit.timeline
        return edit.suggestions.filter { suggestion in
            guard suggestion.kind == .pause, let extent = timeline.playedExtent(of: suggestion.sourceID) else { return false }
            return suggestion.span.start >= extent.start && suggestion.span.end <= extent.end
                && SilenceDetector.silenceLength(ofCut: suggestion.span) < pauseThreshold - 0.001
        }.count
    }

    /// "3 to review" or "All clean".
    var reviewTitle: String {
        let count = pendingSuggestions.count
        return count == 0 ? String(localized: "All clean") : String(localized: "\(count) to review")
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

    /// Where a suggestion sits on the edited timeline; nil once it no longer plays.
    func editedStart(of suggestion: CleanUpSuggestion) -> TimeInterval? {
        guard suggestion.status != .removed, !edit.timeline.isRemoved(suggestion) else { return nil }
        return edit.timeline.editedTime(following: suggestion.span.start, in: suggestion.sourceID)
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
        if !timeline.isRemoved(suggestion) {
            guard timeline.remove([suggestion]) else {
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
        guard timeline.remove(sure) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        let left = pending.count - sure.count
        commit(timeline, suggestions: deciding(Set(sure.map(\.id)), .removed))
        toast.show(left > 0
            ? String(localized: "Removed \(sure.count) · \(left) to review")
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
