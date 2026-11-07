//
//  ClipsViewModel+CleanUp.swift
//  Cue Studio
//

import Foundation

/// Clean Up: pauses, filler words and possible retakes found in the take and, in a montage, in every other recording it
/// plays, as suggestions Pauses marks and removes (`ClipsViewModel+Pauses`). Each suggestion stays with its
/// recording: cuts, a new order, copies and speed move where it plays, never what it is.
extension ClipsViewModel {
    static let pauseThresholdRange: ClosedRange<TimeInterval> = 0.3...3

    // MARK: - Analysis

    /// The script a recording is heard against and the language it's heard in: the take's own, or a montage's other take's
    /// (`ClipSource.script`); a video without a script is heard in the take's language.
    func cleanUpScript(of source: UUID?) -> (script: Script?, language: SpeechLanguageRequest) {
        guard let source else { return (captionScript, speechLanguage) }
        guard let script = edit.sources.first(where: { $0.id == source })?.script(takes: takes, library: library) else {
            return (nil, speechLanguage)
        }
        return (script, speechLanguageFor(script))
    }

    /// Starts listening for Clean Up (`analyzeIfNeeded`) unless it already is: opening Pauses, and its Try again.
    func listenForCleanUp() {
        guard !jobs.isRunning(.cleanUp) else { return }
        jobs.start(.cleanUp) { [weak self] _ in await self?.analyzeIfNeeded() }
    }

    /// Listens to each recording the edit plays the first time Clean Up opens on it (the take, then a montage's other takes
    /// and videos): loudness for pauses, the transcript (in the Voice Following language, or the script's) for filler words and
    /// retakes, and each recording's own script for its lines said more than once (`cleanUpScript`). Nothing is removed. A
    /// recording that can't be listened to leaves the others' suggestions in. What it learned about the take's words is kept
    /// (`TakeEdit.cleanUpHearing`), and how sure it could be of each recording's pauses (`TakeEdit.pauseHearings`, D16).
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
        var hearing: CleanUpHearing?
        var hearings: [RecordingPauseHearing] = []
        var failed = false
        for source in pending {
            let file: URL? = if let source { urls[source] } else { videoURL }
            guard let url = file else { continue }
            do {
                // Each recording's own script finds its lines said more than once, in its language: the take's, a montage's other
                // take's (owner, 07/11/2026); a video brought in has none and is heard in the take's language.
                let (script, language) = cleanUpScript(of: source)
                let heard = try await editing.cleanUpFindings(forVideoAt: url, language: language, script: script?.text ?? "")
                found += heard.suggestions.map { suggestion in
                    var mine = suggestion
                    mine.sourceID = source
                    return mine
                }
                if source == nil { hearing = heard.hearing }
                listened.append(source)
                if heard.pauseHearing != .clear { hearings.append(RecordingPauseHearing(sourceID: source, hearing: heard.pauseHearing)) }
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
            // How each recording heard now was heard replaces what was kept about it; the cuts already made stay as they are.
            analyzed.pauseHearings = analyzed.pauseHearings.filter { !listened.contains($0.sourceID) } + hearings
            for source in listened {
                if let source { analyzed.cleanUpAnalyzedSources.append(source) } else { analyzed.cleanUpAnalyzed = true }
            }
            if let hearing { analyzed.cleanUpHearing = hearing }
        }
        if failed, listened.isEmpty {
            analysis = .failed
            toast.show(String(localized: "Couldn't listen to this take"), kind: .problem)
            return
        }
        analysis = .done
        if failed { toast.show(String(localized: "Couldn't listen to every clip"), kind: .problem) }
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
            .filter { $0.kind != .pause || SilenceDetector.silenceLength(of: $0) >= pauseThreshold - 0.001 }
            .sorted { playOrder($0) < playOrder($1) }
    }

    /// How sure Clean Up could be of the pauses of the recordings the edit plays (D16): the most careful of them, so a montage with
    /// one take recorded beside a fan says so. `.tooMuchBackgroundSound` means "no pauses" isn't "the take flows"; with
    /// `.overBackgroundSound` or `.softVoice` the pauses it lists wait for a listen, none marked (`PauseHearing.title`, `.detail`).
    var cleanUpPauseHearing: PauseHearing {
        let played = edit.playedRecordingIDs
        return edit.pauseHearings.filter { played.contains($0.sourceID) }.map(\.hearing).max { $0.caution < $1.caution } ?? .clear
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
