//
//  QuickEditViewModel+CleanUp.swift
//  Cue Studio
//

import Foundation

/// Clean Up: pauses, filler words and possible retakes found in the take and, in a montage, in every other recording it
/// plays, as suggestions Pauses marks and removes (`QuickEditViewModel+PausesPanel`). Each suggestion stays with its
/// recording: cuts, a new order, copies and speed move where it plays, never what it is.
extension QuickEditViewModel {
    static let pauseThresholdRange: ClosedRange<TimeInterval> = 0.3...3

    // MARK: - Analysis

    /// Starts listening for Clean Up (`analyzeIfNeeded`) unless it already is: opening Pauses, and its Try again.
    func listenForCleanUp() {
        guard !jobs.isRunning(.cleanUp) else { return }
        jobs.start(.cleanUp) { [weak self] _ in await self?.analyzeIfNeeded() }
    }

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
                // Stopped by leaving the editor: not a failure to report.
                guard !Task.isCancelled, !isClosed else { return }
                noteFailure(error, "cleanUp")
                failed = true
            }
            guard !isClosed else { return }
        }
        updateFindings { analyzed in
            // Only the recordings listened to now get fresh suggestions; the others keep theirs.
            let kept = analyzed.suggestions.filter { !listened.contains($0.sourceID) }
            let heard = analyzed.suggestions.filter { listened.contains($0.sourceID) }
            analyzed.suggestions = kept + CleanUpAnalyzer.merged(found, into: heard)
            for source in listened {
                if let source { analyzed.cleanUpAnalyzedSources.append(source) } else { analyzed.cleanUpAnalyzed = true }
            }
        }
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

    // MARK: - Threshold

    func lowerPauseThreshold() {
        setPauseThreshold(pauseThreshold - 0.1)
    }

    func raisePauseThreshold() {
        setPauseThreshold(pauseThreshold + 0.1)
    }

    // MARK: - Private

    private func setPauseThreshold(_ value: TimeInterval) {
        let tenths = (value * 10).rounded() / 10
        pauseThreshold = min(Self.pauseThresholdRange.upperBound, max(Self.pauseThresholdRange.lowerBound, tenths))
    }
}
