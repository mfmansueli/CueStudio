//
//  CaptionsViewModel+Lines.swift
//  Cue Studio
//

import Foundation

/// Captions: made from what is said in the take (the script, when there is one, only lends its
/// spelling), then read and corrected line by line. Making them can be stopped; a failure or a stop
/// leaves the lines as they were, and lines the creator corrected are only replaced after asking.
/// Every change to the lines is an undo step.
extension CaptionsViewModel {
    // MARK: - Making captions

    /// The language captions listen in: the one picked for this take, else the script's (its own,
    /// or read from its text). Never Voice Following's or the interface's.
    var captionSpeechLanguage: SpeechLanguageRequest {
        edit.captionLanguage.map(SpeechLanguageRequest.language) ?? speechLanguageFor(session.captionScript)
    }

    /// Lines the creator corrected or wrote, which new captions would replace.
    var hasRevisedCaptions: Bool {
        edit.captions.contains { $0.isRevised || $0.origin == .manual }
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
        let recordings = captionRecordings
        let isAuto = edit.captionLanguage == nil
        captionState = .working(.preparing)
        jobs.start(.captions) { [weak self, editing] request in
            guard let self else { return }
            // Progress arrives from the recognizer's own tasks; it only lands while this request is on.
            let report: @Sendable (CaptionProgress) -> Void = { [weak self] progress in
                Task { @MainActor in self?.receiveCaptionProgress(progress, for: request) }
            }
            var outcomes: [(source: UUID?, outcome: CaptionOutcome)] = []
            do {
                for recording in recordings {
                    try Task.checkCancellation()
                    let outcome: CaptionOutcome
                    if let cached = transcript(of: recording.source), canReuse(cached, for: recording.language, among: isAuto ? recording.candidates : []) {
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
                            forVideoAt: recording.url, script: recording.script, language: recording.language,
                            spokenAmong: recording.candidates, progress: report
                        )
                    }
                    outcomes.append((recording.source, outcome))
                }
            } catch is CancellationError {
                finishCaptions(request, with: .cancelled)
                return
            } catch {
                noteFailure(error, "captions")
                finishCaptions(request, with: .failed)
                return
            }
            finishCaptions(request, outcomes: outcomes, takeCandidates: recordings.first?.candidates ?? [])
        }
    }

    /// The languages captions hear the first seconds of a recording in, to listen to it in the one spoken (none: it's heard in
    /// `language` straight away). On Auto, a take without a script: its likely languages. A language picked unlike the script's
    /// (most likely by mistake, as the take was read in the script's): the script's first, then the one picked.
    private func spokenCandidates(for script: Script?) -> [CueLanguage] {
        guard let chosen = edit.captionLanguage else { return likelySpokenLanguagesFor(script) }
        guard script != nil, let written = SpeechLocaleResolver.target(for: speechLanguageFor(script))?.language, written != chosen else {
            return []
        }
        return [written, chosen]
    }

    /// What captions listen to: the take (with its script), then each other recording the montage
    /// plays (a library take with its own script, a video with none).
    private var captionRecordings: [CaptionRecording] {
        let take = CaptionRecording(
            source: nil, url: session.videoURL, script: scriptText, language: captionSpeechLanguage,
            candidates: spokenCandidates(for: session.captionScript)
        )
        var result = [take]
        for source in edit.sources where edit.timeline.segments.contains(where: { $0.sourceID == source.id }) {
            let script = source.scriptReference ?? source.takeID
                .flatMap { id in takes.takes.first { $0.id == id } }
                .flatMap { $0.captionScript(current: library.script(id: $0.scriptID)) }
            let language = edit.captionLanguage.map(SpeechLanguageRequest.language) ?? speechLanguageFor(script)
            result.append(CaptionRecording(
                source: source.id, url: EditMediaFiles.url(for: source.fileName), script: script?.text ?? "", language: language,
                candidates: spokenCandidates(for: script)
            ))
        }
        return result
    }

    /// A transcript already made: in the language asked for, or (on Auto) in one of the languages the recording is likely spoken in.
    private func canReuse(_ transcript: CaptionTranscript, for language: SpeechLanguageRequest, among candidates: [CueLanguage]) -> Bool {
        guard transcript.isCurrent else { return false }
        let heard = CueLanguage.matching(languageCode: transcript.languageCode)
        if let heard, candidates.contains(heard) { return true }
        switch language {
        case .language(let chosen): return heard == chosen
        case .detect: return true
        }
    }

    /// Stops listening. The lines stay as they were.
    func cancelCaptions() {
        guard captionState.isWorking else { return }
        jobs.cancel(.captions)
        captionState = .cancelled
    }

    /// Picks the language spoken in the take (nil: the script's), as an undo step. Listening in another language stops, so
    /// its result can't land on this choice.
    func setCaptionLanguage(_ language: CueLanguage?) {
        guard language != edit.captionLanguage else { return }
        if captionState.isWorking { cancelCaptions() }
        changeEdit { $0.captionLanguage = language }
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

    /// Selecting a look never enables transcription. Generation has its own explicit control.
    /// With `reveal` (the way of showing words a complete preset brings), both change in the same
    /// undo step, so one Undo goes back to the look before, never to a mix of the two.
    func setCaptionTheme(_ theme: CaptionTheme, reveal: CaptionAnimation? = nil) {
        let aspect = edit.aspect
        change { snapshot in
            let before = snapshot.captionCollection
            var settings = CaptionSettings(theme: theme)
            settings.center = before?.center
            settings.safeMargins = before?.safeMargins ?? captionSafeMargins
            // The format is how the lines are cut, not a look: it stays.
            settings.format = before?.format
            if let reveal {
                settings.followsWords = reveal.followsWords
                snapshot.captionAnimation = reveal
            }
            snapshot.captionCollection = settings
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        toast.show(String(localized: "\(theme.label) on the captions"))
    }

    func updateCaptionSettings(_ update: (inout CaptionSettings) -> Void) {
        let aspect = edit.aspect
        change { snapshot in
            guard var settings = snapshot.captionCollection else { return }
            let before = settings
            update(&settings)
            snapshot.captionCollection = settings
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
    }

    func resetCaptionTheme() {
        guard let theme = edit.captionCollection?.theme else { return }
        let aspect = edit.aspect
        change { snapshot in
            let before = snapshot.captionCollection
            var settings = CaptionSettings(theme: theme)
            settings.safeMargins = before?.safeMargins ?? captionSafeMargins
            settings.format = before?.format
            snapshot.captionCollection = settings
            snapshot.captionPosition = .bottom
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
    }

    var captionSafeMargins: SafeZoneMargins {
        Self.captionSafeMargins(for: session.take, aspect: edit.aspect)
    }

    static func captionSafeMargins(for take: Take, aspect: AspectRatio) -> SafeZoneMargins {
        CaptionSafeArea.margins(for: take, aspect: aspect)
    }

    private func receiveCaptionProgress(_ progress: CaptionProgress, for request: EditorJobs.Ticket) {
        guard jobs.isCurrent(request), captionState.isWorking else { return }
        captionState = .working(progress)
    }

    private func finishCaptions(_ request: EditorJobs.Ticket, with state: CaptionState) {
        // A newer request, a stop or a closed editor: this result is no longer wanted.
        guard jobs.isCurrent(request) else { return }
        captionState = state
    }

    /// Lines from every recording that gave some; when none did, the take's own reason.
    private func finishCaptions(
        _ request: EditorJobs.Ticket, outcomes: [(source: UUID?, outcome: CaptionOutcome)], takeCandidates: [CueLanguage]
    ) {
        guard jobs.isCurrent(request) else { return }
        var lines: [CaptionCue] = []
        var takeTranscript: CaptionTranscript?
        var others: [CaptionTranscript] = []
        var unheard: [String] = []
        for (source, outcome) in outcomes {
            guard case .captions(let found, var transcript) = outcome else { continue }
            transcript.sourceID = source
            for code in transcript.unheardLanguages ?? [] where !unheard.contains(code) { unheard.append(code) }
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
        updateFindings { edit in
            edit.captionTranscript = takeTranscript
            edit.sourceTranscripts = others
        }
        // One undo step: the lines, shown (unless hidden while they were made) and, for a language picked unlike the one
        // spoken, the picker saying the one they were heard in.
        let spoken = (takeTranscript?.languageCode).flatMap { code in takeCandidates.first { CueLanguage.matching(languageCode: code) == $0 } }
        let shows = !keepsCaptionsHiddenAfterListening
        keepsCaptionsHiddenAfterListening = false
        var made = snapshot
        startsCaptionsInMyStyle(&made)
        lines.sort { $0.start < $1.start }
        // New lines are cut by the edit's format (My style's, else short phrases); an edit from before formats that already had
        // lines keeps making them its way until a format is picked.
        if var settings = made.captionCollection, settings.format != nil || edit.captions.isEmpty {
            let format = settings.format ?? .phrase
            settings.format = format
            made.captionCollection = settings
            lines = Self.blocked(lines, format: format, settings: settings, aspect: edit.aspect)
        }
        changeEdit { edit in
            edit.apply(made)
            edit.captions = lines
            edit.showsCaptions = shows
            if edit.captionLanguage != nil, let spoken { edit.captionLanguage = spoken }
        }
        // Lines made, but a language they should have had was left out: the creator is told, never left to find out.
        captionState = unheard.isEmpty ? .idle : .missingLanguages(unheard)
        // Auto captions turns into the list of the new lines.
        if panel == .autoCaptions { panel = .captions }
        toast.show(String(localized: "\(lines.count) lines to check"))
    }

    // MARK: - Reading

    /// The lines timed to the edit (`CaptionMap`), worked out once per change of the lines or the cuts: a take of an hour has
    /// hundreds, read every frame and every move of a finger.
    var captionMap: CaptionMap {
        // Read here, so a view showing lines draws again when the edit changes.
        let edit = edit
        if let map = captionMapStore { return map }
        let map = CaptionMap(edit)
        captionMapStore = map
        return map
    }

    /// The lines in the order they play, with where (edited seconds); lines said in cut pieces are
    /// left out.
    var editedCaptionLines: [CaptionCue] {
        captionMap.lines
    }

    /// The line a caption shown in the edit comes from (a copy of a section shows it again under
    /// another identity).
    func captionCueID(forLine id: UUID) -> UUID {
        captionMap.cueID(forLine: id)
    }

    /// Where the line plays in the edit (edited seconds); nil when it was cut.
    func editedSpan(ofCaption id: UUID) -> TimeSpan? {
        captionMap.line(id)?.span
    }

    // MARK: - Correcting

    /// New words for a line: the times the voice gave are kept where the words still match.
    func setCaptionText(_ id: UUID, _ text: String) {
        updateCaption(id, key: "captionText.\(id)") { CaptionRevision.retimed($0, text: text) }
    }

    /// Moves a line's start or end by `seconds` of the edit, never past its neighbors, the other
    /// end or the clip it shows in (a line's times are of its own recording). Its word times stay: a
    /// line moved by hand keeps its words where the voice put them.
    func nudgeCaption(_ id: UUID, edge: TrimHandle, by seconds: TimeInterval) {
        guard let span = editedSpan(ofCaption: id) else { return }
        let timeline = edit.timeline
        let lines = editedCaptionLines
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        // The clip the line shows in: its edge moves inside it, at its speed.
        let piece = timeline.segmentIndex(atEdited: edge == .start ? span.start : max(span.start, span.end - 0.000_1))
        let pieceStart = timeline.editedStart(ofSegmentAt: piece)
        let segment = timeline.segments[piece]
        let floor = max(index > 0 ? lines[index - 1].end : 0, edge == .start ? pieceStart : 0)
        let ceiling = min(index + 1 < lines.count ? lines[index + 1].start : edit.editedDuration, pieceStart + segment.duration)
        func source(_ edited: TimeInterval) -> TimeInterval {
            min(max(segment.sourceStart, segment.sourceStart + segment.sourceOffset(forEdited: edited - pieceStart)), segment.sourceEnd)
        }
        updateCaption(id, key: "captionNudge.\(id).\(edge)") { cue in
            var revised = cue
            guard segment.sourceID == cue.sourceID else { return cue }
            switch edge {
            case .start:
                revised.start = source(min(max(floor, span.start + seconds), span.end - CaptionCue.minimumDuration))
            case .end:
                revised.end = source(max(min(ceiling, span.end + seconds), span.start + CaptionCue.minimumDuration))
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

    /// Splits a line before its word at `index`. Both parts were cut by hand: a caption format leaves them as they are.
    func splitCaption(_ id: UUID, beforeWord index: Int) {
        change { snapshot in
            guard var lines = snapshot.captions, let position = lines.firstIndex(where: { $0.id == id }),
                  var (first, second) = CaptionRevision.split(lines[position], beforeWord: index) else { return }
            first.keepsBlock = true
            second.keepsBlock = true
            lines[position] = first
            lines.insert(second, at: position + 1)
            snapshot.captions = lines
        }
    }

    /// Joins a line with the one that plays after it, when that's the next thing said in the same recording
    /// (`CaptionJoin`). The joined line was made by hand: a caption format leaves it as it is.
    func mergeCaptionWithNext(_ id: UUID) {
        guard case .next(let nextID) = CaptionJoin.next(after: id, in: edit) else { return }
        change { snapshot in
            guard var lines = snapshot.captions, let position = lines.firstIndex(where: { $0.id == id }),
                  let other = lines.firstIndex(where: { $0.id == nextID }) else { return }
            lines[position] = CaptionRevision.merged(lines[position], lines[other])
            lines[position].keepsBlock = true
            lines.remove(at: other)
            snapshot.captions = lines
        }
    }

    func deleteCaption(_ id: UUID) {
        change { snapshot in snapshot.captions?.removeAll { $0.id == id } }
    }

    /// Caption › Split: splits the line at the playhead, between the words nearest to it, and picks
    /// the second part.
    func splitCaptionAtPlayhead(_ id: UUID) {
        guard let cue = edit.captions.first(where: { $0.id == id }) else { return }
        let time = player.currentTime
        // The part of the line under the playhead (a copied clip shows it again).
        let instances = captionMap.instances.filter { $0.cueID == id }
        guard let span = (instances.first { $0.line.span.contains(time) } ?? instances.first)?.line.span else { return }
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
        sayUndoable(String(localized: "Line split"))
    }

    /// Caption line › Word timing: where word `index` ends and the next one starts (seconds of the recording), never closer than
    /// a tenth to their other ends. The two words now have times the creator set (no longer estimated), the line is revised and
    /// stops asking for a timing check once none of its words is estimated; one undo step a drag.
    func setWordBoundary(_ id: UUID, after index: Int, at time: TimeInterval) {
        updateCaption(id, key: "wordTiming.\(id).\(index)") { cue in
            var words = cue.lineWords
            guard words.indices.contains(index + 1) else { return cue }
            let low = words[index].start + 0.1
            let high = words[index + 1].end - 0.1
            guard low < high else { return cue }
            let boundary = min(max(time, low), high)
            words[index] = CaptionWord(text: words[index].text, start: words[index].start, end: boundary)
            words[index + 1] = CaptionWord(text: words[index + 1].text, start: boundary, end: words[index + 1].end)
            var timed = cue
            timed.words = words
            timed.isRevised = true
            if !words.contains(where: \.isEstimated) { timed.needsTimingReview = false }
            return timed
        }
    }

    /// Caption › Line break: the line goes on a new line before the word at `offset` (a character of its text, where the cursor
    /// is; nil: the word at the playhead), in the same caption. Return still goes on to the next caption. A line broken by hand
    /// keeps its edges whatever the format; deleting the break in the text takes it out.
    func breakCaptionLine(_ id: UUID, atCharacter offset: Int?) {
        guard let cue = edit.captions.first(where: { $0.id == id }) else { return }
        let words = CaptionText.words(in: cue.text)
        guard words.count > 1 else {
            toast.show(String(localized: "Only one word here"))
            return
        }
        let before: Int
        if let offset {
            let typed = String(cue.text.prefix(max(0, offset)))
            let count = CaptionText.words(in: typed).count
            before = (typed.last?.isWhitespace ?? true) ? count : count - 1
        } else {
            before = CaptionRevision.splitIndex(of: cue, atSource: edit.timeline.sourceTime(forEdited: player.currentTime))
        }
        let index = min(max(1, before), words.count - 1)
        var breaks = cue.lineBreaks
        breaks.insert(index - 1)
        let text = CaptionText.joined(words, breaks: breaks)
        updateCaption(id) { cue in
            var broken = CaptionRevision.retimed(cue, text: text)
            broken.keepsBlock = true
            return broken
        }
        sayUndoable(String(localized: "Line break added"))
    }

    /// Caption › Join next.
    func joinCaption(_ id: UUID) {
        if let refusal = CaptionJoin.next(after: id, in: edit).refusal {
            toast.show(refusal)
            return
        }
        mergeCaptionWithNext(id)
        sayUndoable(String(localized: "Joined with next line"))
    }

    /// Caption › Delete.
    func deleteCaptionLine(_ id: UUID) {
        selection = nil
        deleteCaption(id)
        Haptics.delete()
        sayUndoable(String(localized: "Line deleted"))
    }

    /// What was heard in a recording (nil: the take itself).
    private func transcript(of source: UUID?) -> CaptionTranscript? {
        guard let source else { return edit.captionTranscript }
        return edit.sourceTranscripts.first { $0.sourceID == source }
    }

    private func updateCaption(_ id: UUID, key: String? = nil, _ update: (CaptionCue) -> CaptionCue) {
        change(key: key) { snapshot in
            guard var lines = snapshot.captions, let position = lines.firstIndex(where: { $0.id == id }) else { return }
            lines[position] = update(lines[position])
            snapshot.captions = lines
        }
    }
}
