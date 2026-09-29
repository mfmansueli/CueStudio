//
//  QuickEditViewModel+Captions.swift
//  Cue Studio
//

import Foundation

/// Captions: made from what is said in the take (the script, when there is one, only lends its
/// spelling), then read and corrected line by line. Making them can be stopped; a failure or a stop
/// leaves the lines as they were, and lines the creator corrected are only replaced after asking.
/// Every change to the lines is an undo step.
extension QuickEditViewModel {
    // MARK: - Making captions

    /// The language captions listen in: the one picked for this take, else Voice Following's or the
    /// script's. Never the interface's.
    var captionSpeechLanguage: SpeechLanguageRequest {
        edit.captionLanguage.map(SpeechLanguageRequest.language) ?? speechLanguage
    }

    /// Lines the creator corrected or wrote, which new captions would replace.
    var hasRevisedCaptions: Bool {
        edit.captions.contains { $0.isRevised || $0.origin == .manual }
    }

    /// Shows or hides the captions; the first time they show, they are made from the take.
    func setShowsCaptions(_ shows: Bool) async {
        edit.showsCaptions = shows
        guard shows, edit.captions.isEmpty, !captionState.isWorking else { return }
        makeCaptions()
        await captionTask?.value
    }

    /// Listens to the take and makes the lines. Asks first when that would replace lines the
    /// creator corrected (`confirmsCaptionReplacement`), unless `replacingRevised`.
    func makeCaptions(replacingRevised: Bool = false) {
        guard isReady, !captionState.isWorking else { return }
        if hasRevisedCaptions, !replacingRevised {
            confirmsCaptionReplacement = true
            return
        }
        let request = UUID()
        captionRequest = request
        let url = videoURL
        let script = scriptText
        let language = captionSpeechLanguage
        captionState = .working(.preparing)
        // Progress arrives from the recognizer's own tasks; it only lands while this request is on.
        let report: @Sendable (CaptionProgress) -> Void = { [weak self] progress in
            Task { @MainActor in self?.receiveCaptionProgress(progress, for: request) }
        }
        captionTask = Task { [editing] in
            let outcome: CaptionOutcome
            do {
                outcome = try await editing.captions(forVideoAt: url, script: script, language: language, progress: report)
            } catch is CancellationError {
                finishCaptions(request, with: .cancelled)
                return
            } catch {
                finishCaptions(request, with: .failed)
                return
            }
            finishCaptions(request, outcome: outcome)
        }
    }

    /// Stops listening. The lines stay as they were.
    func cancelCaptions() {
        guard captionState.isWorking else { return }
        captionRequest = nil
        captionTask?.cancel()
        captionState = .cancelled
    }

    /// Picks the language spoken in the take (nil: Voice Following's or the script's). Listening in
    /// another language stops, so its result can't land on this choice.
    func setCaptionLanguage(_ language: CueLanguage?) {
        guard language != edit.captionLanguage else { return }
        if captionState.isWorking { cancelCaptions() }
        edit.captionLanguage = language
        captionState = .idle
    }

    /// A preset for the captions (one undo step); turns them on when they were off.
    func setCaptionPreset(_ preset: TypePreset) async {
        applyPreset(preset, to: .allCaptions)
        if !edit.showsCaptions { await setShowsCaptions(true) }
    }

    private func receiveCaptionProgress(_ progress: CaptionProgress, for request: UUID) {
        guard captionRequest == request, captionState.isWorking else { return }
        captionState = .working(progress)
    }

    private func finishCaptions(_ request: UUID, with state: CaptionState) {
        // A newer request, a stop or a closed editor: this result is no longer wanted.
        guard captionRequest == request, !isClosed else { return }
        captionRequest = nil
        captionState = state
    }

    private func finishCaptions(_ request: UUID, outcome: CaptionOutcome) {
        guard captionRequest == request, !isClosed else { return }
        captionRequest = nil
        switch outcome {
        case .captions(let lines, let transcript):
            change { $0.captions = lines }
            edit.captionTranscript = transcript
            edit.showsCaptions = true
            captionState = .idle
            toast.show(String(localized: "Captions made from your voice"))
        case .noAudio:
            captionState = .noAudio
        case .noSpeech:
            captionState = .noSpeech
        case .unavailable(let reason):
            captionState = .unavailable(reason)
        }
    }

    // MARK: - Reading

    /// The lines in the order they play, with where (edited seconds); lines said in cut pieces are
    /// left out.
    var editedCaptionLines: [CaptionCue] {
        edit.editedCaptions.sorted { $0.start < $1.start }
    }

    var editingCaption: CaptionCue? {
        editingCaptionID.flatMap { id in edit.captions.first { $0.id == id } }
    }

    /// What was heard over the line's time, before any correction; nil for a line written by hand
    /// or when nothing was heard there.
    func heardText(of cue: CaptionCue) -> String? {
        guard cue.origin == .speech, let transcript = edit.captionTranscript else { return nil }
        let heard = transcript.text(in: cue.span)
        return heard.isEmpty ? nil : heard
    }

    /// Where the line plays in the edit (edited seconds); nil when it was cut.
    func editedSpan(ofCaption id: UUID) -> TimeSpan? {
        edit.editedCaptions.first { $0.id == id }?.span
    }

    /// Shows the line on the preview.
    func showCaption(_ id: UUID) {
        guard let span = editedSpan(ofCaption: id) else { return }
        player.pause()
        player.seek(to: span.start)
    }

    // MARK: - Correcting

    /// A new line at the playhead, written by hand (the way to caption a take no model can hear),
    /// open for writing.
    func addCaption() {
        guard isReady else { return }
        player.pause()
        let span = edit.timeline.sourceSpan(forEdited: placement(at: player.currentTime, length: 2))
        let cue = CaptionCue(text: "", start: span.start, end: span.end, origin: .manual)
        change { snapshot in
            var lines = snapshot.captions ?? []
            lines.append(cue)
            snapshot.captions = lines.sorted { $0.start < $1.start }
        }
        edit.showsCaptions = true
        editingCaptionID = cue.id
    }

    /// New words for a line: the times the voice gave are kept where the words still match.
    func setCaptionText(_ id: UUID, _ text: String) {
        updateCaption(id) { CaptionRevision.retimed($0, text: text) }
    }

    /// Moves a line's start or end by `seconds` of the edit, never past its neighbors or the other
    /// end. Its word times stay: a line moved by hand keeps its words where the voice put them.
    func nudgeCaption(_ id: UUID, edge: TrimHandle, by seconds: TimeInterval) {
        guard let span = editedSpan(ofCaption: id) else { return }
        let timeline = edit.timeline
        let lines = editedCaptionLines
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let floor = index > 0 ? lines[index - 1].end : 0
        let ceiling = index + 1 < lines.count ? lines[index + 1].start : edit.editedDuration
        updateCaption(id) { cue in
            var revised = cue
            switch edge {
            case .start:
                let edited = min(max(floor, span.start + seconds), span.end - CaptionCue.minimumDuration)
                revised.start = timeline.sourceTime(forEdited: edited)
            case .end:
                let edited = max(min(ceiling, span.end + seconds), span.start + CaptionCue.minimumDuration)
                revised.end = timeline.sourceTime(forEdited: edited)
            }
            revised.isRevised = true
            // Words now outside the line's time can't be lit where they were.
            if revised.words.contains(where: { $0.start < revised.start - 0.01 || $0.end > revised.end + 0.01 }) {
                revised.needsTimingReview = true
            }
            return revised
        }
    }

    /// Splits a line before its word at `index`.
    func splitCaption(_ id: UUID, beforeWord index: Int) {
        change { snapshot in
            guard var lines = snapshot.captions, let position = lines.firstIndex(where: { $0.id == id }),
                  let (first, second) = CaptionRevision.split(lines[position], beforeWord: index) else { return }
            lines[position] = first
            lines.insert(second, at: position + 1)
            snapshot.captions = lines
        }
    }

    /// Joins a line with the one after it.
    func mergeCaptionWithNext(_ id: UUID) {
        change { snapshot in
            guard var lines = snapshot.captions?.sorted(by: { $0.start < $1.start }),
                  let position = lines.firstIndex(where: { $0.id == id }), position + 1 < lines.count else { return }
            lines[position] = CaptionRevision.merged(lines[position], lines[position + 1])
            lines.remove(at: position + 1)
            snapshot.captions = lines
        }
    }

    func deleteCaption(_ id: UUID) {
        change { snapshot in snapshot.captions?.removeAll { $0.id == id } }
        if editingCaptionID == id { editingCaptionID = nil }
    }

    /// Puts back what was heard over the line's time (its correction undone as a new step).
    func restoreHeardText(_ id: UUID) {
        guard let transcript = edit.captionTranscript,
              let cue = edit.captions.first(where: { $0.id == id }), cue.origin == .speech else { return }
        let words = transcript.words.filter { $0.end > cue.start + 0.01 && $0.start < cue.end - 0.01 }
        guard !words.isEmpty else { return }
        updateCaption(id) { old in
            var heard = CaptionCue(words: words)
            heard.id = old.id
            return heard
        }
    }

    /// Whether the line can be joined with the next one.
    func canMergeCaption(_ id: UUID) -> Bool {
        let lines = edit.captions.sorted { $0.start < $1.start }
        guard let position = lines.firstIndex(where: { $0.id == id }) else { return false }
        return position + 1 < lines.count
    }

    /// The editing sheet closed: a line left empty goes.
    func endEditingCaption() {
        if let id = editingCaptionID, let cue = edit.captions.first(where: { $0.id == id }),
           cue.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deleteCaption(id)
        }
        editingCaptionID = nil
        endChange()
    }

    private func updateCaption(_ id: UUID, _ update: (CaptionCue) -> CaptionCue) {
        change { snapshot in
            guard var lines = snapshot.captions, let position = lines.firstIndex(where: { $0.id == id }) else { return }
            lines[position] = update(lines[position])
            snapshot.captions = lines
        }
    }
}
