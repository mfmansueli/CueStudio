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

    /// The language captions listen in: the one picked for this take, else the script's (its own,
    /// or read from its text). Never Voice Following's or the interface's.
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
        if !shows {
            cancelCaptions() // A late recognition result must not turn captions back on.
            return
        }
        guard edit.captions.isEmpty, !captionState.isWorking else { return }
        makeCaptions()
        await captionTask?.value
    }

    /// Listens to the take (and a montage's other recordings) and makes the lines. Asks first when
    /// that would replace lines the creator corrected (`confirmsCaptionReplacement`), unless
    /// `replacingRevised`.
    func makeCaptions(replacingRevised: Bool = false) {
        guard isReady, !captionState.isWorking else { return }
        if hasRevisedCaptions, !replacingRevised {
            confirmsCaptionReplacement = true
            return
        }
        let request = UUID()
        captionRequest = request
        let recordings = captionRecordings
        captionState = .working(.preparing)
        // Progress arrives from the recognizer's own tasks; it only lands while this request is on.
        let report: @Sendable (CaptionProgress) -> Void = { [weak self] progress in
            Task { @MainActor in self?.receiveCaptionProgress(progress, for: request) }
        }
        captionTask = Task { [editing] in
            var outcomes: [(source: UUID?, outcome: CaptionOutcome)] = []
            do {
                for recording in recordings {
                    try Task.checkCancellation()
                    let outcome: CaptionOutcome
                    if let cached = transcript(of: recording.source), canReuse(cached, for: recording.language) {
                        // Lining the words up with the script (spelling, languages) is the same work
                        // `TakeEditService` does after listening: off the main actor, like there.
                        let words = cached.words
                        let script = recording.script
                        let language = CueLanguage.matching(languageCode: cached.languageCode)
                        let lines = await Task.detached { CaptionBuilder.captions(heard: words, script: script, language: language) }.value
                        try Task.checkCancellation()
                        outcome = .captions(lines, transcript: cached)
                    } else {
                        outcome = try await editing.captions(
                            forVideoAt: recording.url, script: recording.script, language: recording.language, progress: report
                        )
                    }
                    outcomes.append((recording.source, outcome))
                }
            } catch is CancellationError {
                finishCaptions(request, with: .cancelled)
                return
            } catch {
                finishCaptions(request, with: .failed)
                return
            }
            finishCaptions(request, outcomes: outcomes)
        }
    }

    /// What captions listen to: the take (with its script), then each other recording the montage
    /// plays (a library take with its own script, a video with none).
    private var captionRecordings: [(source: UUID?, url: URL, script: String, language: SpeechLanguageRequest)] {
        var result: [(source: UUID?, url: URL, script: String, language: SpeechLanguageRequest)] = [(nil, videoURL, scriptText, captionSpeechLanguage)]
        for source in edit.sources where edit.timeline.segments.contains(where: { $0.sourceID == source.id }) {
            let script = source.scriptReference ?? source.takeID
                .flatMap { id in takes.takes.first { $0.id == id } }
                .flatMap { $0.captionScript(current: library.script(id: $0.scriptID)) }
            let language = edit.captionLanguage.map(SpeechLanguageRequest.language) ?? speechLanguageFor(script)
            result.append((source.id, EditMediaFiles.url(for: source.fileName), script?.text ?? "", language))
        }
        return result
    }

    private func canReuse(_ transcript: CaptionTranscript, for language: SpeechLanguageRequest) -> Bool {
        guard transcript.isCurrent else { return false }
        switch language {
        case .language(let chosen): return CueLanguage.matching(languageCode: transcript.languageCode) == chosen
        case .detect: return true
        }
    }

    /// Stops listening. The lines stay as they were.
    func cancelCaptions() {
        guard captionState.isWorking else { return }
        captionRequest = nil
        captionTask?.cancel()
        captionState = .cancelled
    }

    /// Picks the language spoken in the take (nil: the script's). Listening in another language
    /// stops, so its result can't land on this choice.
    func setCaptionLanguage(_ language: CueLanguage?) {
        guard language != edit.captionLanguage else { return }
        if captionState.isWorking { cancelCaptions() }
        edit.captionLanguage = language
        captionState = .idle
    }

    /// How lines come and go (one undo step). Animations draw with a type preset: captions still in
    /// the old caption style take Cue's.
    func setCaptionAnimation(_ animation: CaptionAnimation) {
        change { snapshot in
            snapshot.captionAnimation = animation
            if snapshot.captionLook == nil, animation != .line {
                snapshot.captionLook = TypePreset.cue.look(for: .caption)
                snapshot.captionPreset = .cue
            }
        }
    }

    /// Lines whose words don't have their own times (written or corrected by hand): the effects go by
    /// their words shared across the line's time.
    var linesWithoutWordTiming: Int {
        edit.captions.filter { !$0.hasWordTiming }.count
    }

    /// A preset for the captions (one undo step); turns them on when they were off.
    func setCaptionPreset(_ preset: TypePreset) async {
        applyPreset(preset, to: .allCaptions)
        if !edit.showsCaptions { await setShowsCaptions(true) }
    }

    /// Selecting a look never enables transcription. Generation has its own explicit control.
    /// With `reveal` (the way of showing words a complete preset brings), both change in the same
    /// undo step, so one Undo goes back to the look before, never to a mix of the two.
    func setCaptionTheme(_ theme: CaptionTheme, reveal: CaptionAnimation? = nil) {
        change { snapshot in
            var settings = CaptionSettings(theme: theme)
            settings.center = snapshot.captionCollection?.center
            settings.safeMargins = snapshot.captionCollection?.safeMargins ?? captionSafeMargins
            if let reveal {
                settings.followsWords = reveal.followsWords
                snapshot.captionAnimation = reveal
            }
            snapshot.captionCollection = settings
        }
        toast.show(String(localized: "\(theme.label) on the captions"))
    }

    func updateCaptionSettings(_ update: (inout CaptionSettings) -> Void) {
        change { snapshot in
            guard var settings = snapshot.captionCollection else { return }
            update(&settings)
            snapshot.captionCollection = settings
        }
    }

    func resetCaptionTheme() {
        guard let theme = edit.captionCollection?.theme else { return }
        change { snapshot in
            var settings = CaptionSettings(theme: theme)
            settings.safeMargins = snapshot.captionCollection?.safeMargins ?? captionSafeMargins
            snapshot.captionCollection = settings
            snapshot.captionPosition = .bottom
        }
    }

    var captionSafeMargins: SafeZoneMargins {
        Self.captionSafeMargins(for: take, aspect: edit.aspect)
    }

    static func captionSafeMargins(for take: Take, aspect: AspectRatio) -> SafeZoneMargins {
        CaptionSafeArea.margins(for: take, aspect: aspect)
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

    /// Lines from every recording that gave some; when none did, the take's own reason.
    private func finishCaptions(_ request: UUID, outcomes: [(source: UUID?, outcome: CaptionOutcome)]) {
        guard captionRequest == request, !isClosed else { return }
        captionRequest = nil
        var lines: [CaptionCue] = []
        var takeTranscript: CaptionTranscript?
        var others: [CaptionTranscript] = []
        for (source, outcome) in outcomes {
            guard case .captions(let found, var transcript) = outcome else { continue }
            transcript.sourceID = source
            lines += found.map { line in
                var tagged = line
                tagged.sourceID = source
                return tagged
            }
            if source == nil { takeTranscript = transcript } else { others.append(transcript) }
        }
        guard !lines.isEmpty else {
            switch outcomes.first?.outcome {
            case .noAudio?: captionState = .noAudio
            case .unavailable(let reason)?: captionState = .unavailable(reason)
            default: captionState = .noSpeech
            }
            return
        }
        change { $0.captions = lines.sorted { $0.start < $1.start } }
        edit.captionTranscript = takeTranscript
        edit.sourceTranscripts = others
        edit.showsCaptions = true
        captionState = .idle
        // Auto captions turns into the list of the new lines.
        if panel == .autoCaptions { panel = .captions }
        toast.show(lines.count == 1
            ? String(localized: "1 line to check")
            : String(localized: "\(lines.count) lines to check"))
    }

    // MARK: - Reading

    /// The lines in the order they play, with where (edited seconds); lines said in cut pieces are
    /// left out.
    var editedCaptionLines: [CaptionCue] {
        edit.editedCaptions.sorted { $0.start < $1.start }
    }

    /// The line a caption shown in the edit comes from (a copy of a section shows it again under
    /// another identity).
    func captionCueID(forLine id: UUID) -> UUID {
        edit.editedCaptionInstances.first { $0.line.id == id }?.cueID ?? id
    }

    /// What was heard over the line's time, before any correction; nil for a line written by hand
    /// or when nothing was heard there.
    func heardText(of cue: CaptionCue) -> String? {
        guard cue.origin == .speech, let transcript = transcript(of: cue.sourceID) else { return nil }
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
        // On the recording that plays there (another take's, in a montage).
        let pinned = edit.timeline.anchoredSpan(forEdited: placement(at: player.currentTime, length: 2))
        var cue = CaptionCue(text: "", start: pinned.span.start, end: pinned.span.end, origin: .manual)
        cue.sourceID = pinned.anchor.sourceID
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
        updateCaption(id, key: "captionText.\(id)") { CaptionRevision.retimed($0, text: text) }
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
        updateCaption(id, key: "captionNudge.\(id).\(edge)") { cue in
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
            // Words now outside the line's time fold into it; the line keeps its look and its words.
            return CaptionRevision.fitted(revised)
        }
    }

    /// Moves or stretches a line on the timeline (`span` in seconds of the recording). A moved
    /// line takes its words along, so the word that lights up stays where it was in the line; a
    /// stretched one folds its words into the new time.
    func moveCaption(_ id: UUID, to span: TimeSpan) {
        updateCaption(id) { cue in
            var moved = cue
            let shift = span.start - cue.start
            let keepsLength = abs(span.duration - (cue.end - cue.start)) < 0.001
            moved.start = span.start
            moved.end = span.end
            if keepsLength, abs(shift) > 0.001 {
                moved.words = cue.words.map { word in
                    CaptionWord(text: word.text, start: word.start + shift, end: word.end + shift, isEstimated: word.isEstimated)
                }
            }
            moved.isRevised = true
            return CaptionRevision.fitted(moved)
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

    /// Caption › Split: splits the line at the playhead, between the words nearest to it, and picks
    /// the second part.
    func splitCaptionAtPlayhead(_ id: UUID) {
        guard let cue = edit.captions.first(where: { $0.id == id }), let span = editedSpan(ofCaption: id) else { return }
        let time = player.currentTime
        guard time > span.start + 0.15, time < span.end - 0.15 else {
            toast.show(String(localized: "Move playhead into the line"))
            return
        }
        let words = CaptionRevision.words(of: cue)
        guard words.count > 1 else {
            toast.show(String(localized: "Only one word here"))
            return
        }
        let source = edit.timeline.sourceTime(forEdited: time)
        let index = CaptionRevision.splitIndex(of: cue, atSource: source)
        let before = Set(edit.captions.map(\.id))
        splitCaption(id, beforeWord: index)
        if let second = edit.captions.first(where: { !before.contains($0.id) }) { selection = .caption(second.id) }
        toast.show(String(localized: "Line split"))
    }

    /// Caption › Join next.
    func joinCaption(_ id: UUID) {
        guard canMergeCaption(id) else {
            toast.show(String(localized: "This is the last line"))
            return
        }
        mergeCaptionWithNext(id)
        toast.show(String(localized: "Joined with next line"))
    }

    /// Caption › Delete.
    func deleteCaptionLine(_ id: UUID) {
        selection = nil
        deleteCaption(id)
        Haptics.delete()
        toast.show(String(localized: "Line deleted"))
    }

    /// What was heard in a recording (nil: the take itself).
    private func transcript(of source: UUID?) -> CaptionTranscript? {
        guard let source else { return edit.captionTranscript }
        return edit.sourceTranscripts.first { $0.sourceID == source }
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

    private func updateCaption(_ id: UUID, key: String? = nil, _ update: (CaptionCue) -> CaptionCue) {
        change(key: key) { snapshot in
            guard var lines = snapshot.captions, let position = lines.firstIndex(where: { $0.id == id }) else { return }
            lines[position] = update(lines[position])
            snapshot.captions = lines
        }
    }
}
