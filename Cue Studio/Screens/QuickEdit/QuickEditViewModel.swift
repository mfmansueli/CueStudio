//
//  QuickEditViewModel.swift
//  Cue Studio
//

import Accessibility
import CoreGraphics
import Foundation

/// Quick edit of one take. The edit is a recipe (`TakeEdit`) on top of the recording, which is never changed, and the player
/// (`EditPlayback`) plays it and owns the playhead. Every decision the creator makes on the edit is an undo step of its
/// document (`EditDocument`); what listening finds is laid on without one. A gesture or a sheet that changes something many
/// times in a row is one undo step (`beginChange` / `endChange`). A draft is kept while editing and when leaving with Cancel;
/// Done saves the edit on the take.
///
/// The editor coordinates its parts (`EditorPart`), each with its own state, working on the edit through the session
/// (`EditorSession`) the editor hosts (`EditorHost`): `CaptionsViewModel`, `CoverViewModel`, `LookViewModel`, `AudioViewModel`,
/// `OverlaysViewModel` and `ClipsViewModel`. What is the editor's own: what is picked and which panel, sheet or menu is open
/// (`show(_:)`, `pick(_:)`), what one part's change means for another (a panel left, the edit changed, the editor closed),
/// what the preview plays, the timeline that draws every part's tracks and its gestures (`+Timeline`, `+Layers`), the
/// toolbar, Undo, and leaving with the draft.
@MainActor
@Observable
final class QuickEditViewModel: EditorHost, EditorPart {
    /// Whether the recording could be opened.
    enum Source: Equatable {
        case loading, ready, unavailable
    }

    // MARK: Editor
    /// The panel open under the timeline, in place of the toolbar. Its ✓ closes it; changes show
    /// live in the preview. Setting it is `show(_:)`.
    var panel: EditorPanel? {
        get { shownPanel }
        set { show(newValue) }
    }
    /// The one thing picked on the timeline or in the preview (a cut included); its tools replace the toolbar's. Setting it
    /// is `pick(_:)`.
    var selection: EditorSelection? {
        get { picked }
        set { pick(newValue) }
    }
    private var shownPanel: EditorPanel?
    private var picked: EditorSelection?
    /// The Text or Audio toolbar, opened from the main one with nothing selected.
    var toolMenu: EditorToolMenu?
    /// The open panel's tab (Text style and Caption style).
    var panelTab: EditorPanelTab = .presets
    /// The open panel's "Advanced" section is expanded.
    var showsAdvanced = false
    /// The preview fills the screen: tap the video to play or pause, outside to come back.
    var isFullScreen = false
    /// The sheet over the editor: Export, Add music, Add photo or video.
    var sheet: EditorSheet? {
        didSet {
            audio.sheetChanged(to: sheet)
        }
    }
    /// The timeline's zoom (44 points per second at 1), from 0.35 to 5.
    var timelineZoom: CGFloat = 1
    /// The timeline handle being dragged.
    var handleDrag: TimelineHandleDrag? {
        didSet {
            if case .clip? = handleDrag?.target { clips.holdsClipHandle = true } else { clips.holdsClipHandle = false }
        }
    }
    /// Where the dragged handle last stuck, so the haptic plays once per snap.
    @ObservationIgnored var lastHandleSnap: TimeInterval?
    /// The styling panels (Text style, Caption style) are expanded: the video gets as small as it
    /// ever gets so the controls have room. Kept while the editor is open.
    var stylePanelIsExpanded = false
    /// The edit and its undo steps (`EditDocument`): the edit changes only there, and this hears each change.
    let document: EditDocument
    private(set) var source: Source = .loading

    /// The Low Power Mode notice over the preview (`QuickEditViewModel+LowPower`).
    var showsLowPowerNotice = false
    /// The creator's handle, for the "@handle" graphic and the cover's series (set by the screen).
    var creatorHandle: String {
        get { session.creatorHandle }
        set { session.creatorHandle = newValue }
    }

    let take: Take
    let player: EditPlayback
    let editing: TakeEditing
    let library: ScriptLibraryService
    let toast: ToastService
    /// Quick edit's own switches, kept between edits.
    let editorPreferences: EditorPreferencesStoring
    /// The library of takes (a montage adds others from it).
    let takes: TakeLibraryService
    private let drafts: QuickEditDraftStoring
    /// What the editor's parts work through: the document, the player, the jobs and the toasts, and this editor as their host.
    let session: EditorSession
    /// Captions: made, corrected, picked, styled, translated and moved on the preview (`CaptionsViewModel`).
    let captions: CaptionsViewModel
    /// The cover: Cover Studio over the editor, and the cover drawn for the timeline's block (`CoverViewModel`).
    let cover: CoverViewModel
    /// The picture: Adjust, Auto, Filters, Background, Format, Stabilize, Copy look (`LookViewModel`).
    let look: LookViewModel
    /// The video track: clips, speed, transitions, montage, reverse, replace, Pauses and Clean Up, Edit by text
    /// (`ClipsViewModel`).
    let clips: ClipsViewModel
    /// The sound: Studio Voice, music and sound effects, beats, voice-overs, a clip's sound pulled out (`AudioViewModel`).
    let audio: AudioViewModel
    /// What lies on the video: texts and graphics, photos and videos, their motion and keyframes, Track, type styles
    /// (`OverlaysViewModel`).
    let overlays: OverlaysViewModel
    /// Where a failure the creator saw is written down (`noteFailure`): Console and Crashlytics; tests read it.
    @ObservationIgnored var reportFailure: (EditorFailureReport) -> Void = { $0.send() }
    /// Everything the editor started and waits for (`EditorJobs`): Auto, captions, Track, the cover, a short preview, the
    /// sound compared, the draft, beats, Clean Up and tools' work. Closing cancels it all.
    @ObservationIgnored let jobs: EditorJobs

    init(
        take: Take, takes: TakeLibraryService, library: ScriptLibraryService, editing: TakeEditing,
        drafts: QuickEditDraftStoring, toast: ToastService, player: EditPlayback? = nil,
        mediaImporter: EditMediaImporting? = nil, recorder: VoiceOverRecording? = nil, styles: TextStyleStoring? = nil,
        editorPreferences: EditorPreferencesStoring? = nil, prompterLook: PrompterSettings = PrompterSettings(),
        coverPictures: CoverPicturing? = nil, soundPreviews: SoundEffectPreviewing? = nil,
        translations: TranslationAvailabilityChecking = AppleTranslationAvailability(), motion: MotionAnalysisService? = nil,
        tracker: ObjectTracking = ObjectTracker(),
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest = SpeechLanguageRequest.script,
        likelySpokenLanguages: @escaping (Script?) -> [CueLanguage] = { _ in [] },
        languageConflict: @escaping (Script?) -> SpeechLanguageConflict? = { _ in nil }
    ) {
        self.take = take
        let styles = styles ?? TextStyleStore()
        let mediaImporter = mediaImporter ?? EditMediaImporter()
        let preferences = editorPreferences ?? EditorPreferencesStore()
        self.editorPreferences = preferences
        self.takes = takes
        self.library = library
        self.editing = editing
        self.drafts = drafts
        self.toast = toast
        var edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        if take.edit == nil { edit.captionCollection?.safeMargins = CaptionsViewModel.captionSafeMargins(for: take, aspect: take.aspect) }
        edit.captions = edit.captions.map(CaptionRevision.withoutContinuation)
        document = EditDocument(edit)
        let player = player ?? QuickEditPlayer(videoURL: takes.videoURL(for: take), editing: editing)
        self.player = player
        let jobs = EditorJobs()
        self.jobs = jobs
        session = EditorSession(
            document: document, player: player, jobs: jobs, toast: toast, take: take, videoURL: takes.videoURL(for: take),
            importer: mediaImporter
        )
        captions = CaptionsViewModel(
            session: session, editing: editing, takes: takes, library: library, styles: styles, translations: translations,
            speechLanguage: speechLanguage, likelySpokenLanguages: likelySpokenLanguages, languageConflict: languageConflict
        )
        cover = CoverViewModel(
            session: session, editing: editing, pictures: coverPictures ?? CoverPictureService(), importer: mediaImporter,
            styles: styles
        )
        look = LookViewModel(session: session, editing: editing, motion: motion)
        clips = ClipsViewModel(session: session, editing: editing, takes: takes, library: library, speechLanguage: speechLanguage)
        overlays = OverlaysViewModel(session: session, importer: mediaImporter, styles: styles, library: library, tracker: tracker)
        audio = AudioViewModel(
            session: session, editing: editing, importer: mediaImporter, recorder: recorder ?? VoiceOverRecorder(),
            editorPreferences: preferences, prompterLook: prompterLook, soundPreviews: soundPreviews ?? SoundEffectPreviewPlayer()
        )
        session.host = self
        self.player.playingStopped = { [weak self] in self?.audio.playingStopped() }
        document.onChange = { [weak self] previous in self?.editChanged(from: previous) }
    }

    /// Opens the recording, picks up a draft left behind and starts the player.
    func prepare() async {
        guard source == .loading else { return }
        let duration: TimeInterval
        do {
            duration = try await editing.sourceDuration(ofVideoAt: videoURL)
        } catch {
            noteFailure(error, "open")
            source = .unavailable
            return
        }
        if let rate = await editing.frameRate(ofVideoAt: videoURL) { session.frameRate = FrameGrid(rate: rate).rate }
        look.recordingUprightSize = await EditFraming.shape(of: videoURL)?.uprightSize
        guard !isClosed else { return }
        // The file's own length wins over the take's saved one; a draft left behind comes back with its undo steps.
        var playhead: TimeInterval = 0
        let draft = drafts.draft(for: take.id)
        if document.open(sourceDuration: duration, draft: draft), let draft {
            playhead = draft.playhead
            toast.show(String(localized: "Draft restored"))
        }
        clips.opened()
        source = .ready
        player.show(edit)
        player.seek(to: playhead)
        cover.drawCover()
        // Only an edit that uses Follow face or Stabilize has its recordings analyzed now; the others when Format or
        // Stabilize opens (an hour of video is a lot to analyze for nothing).
        look.requestMotionAnalysisIfNeeded()
        audio.findBeatsIfNeeded()
    }

    /// The edit changed: what was picked and is gone is let go, and the preview, the draft and the cover follow.
    private func editChanged(from previous: TakeEdit) {
        // Edit by text's picked words, and the lines timed to the edit.
        clips.editChanged(from: previous)
        captions.editChanged(from: previous)
        guard source == .ready else { return }
        if let id = selectedSegmentID, edit.timeline.segment(id: id) == nil { selectedSegmentID = nil }
        if let id = selectedTextID, !edit.texts.contains(where: { $0.id == id }) { selectedTextID = nil }
        if let id = selectedMediaID, !edit.media.contains(where: { $0.id == id }) { selectedMediaID = nil }
        if let id = selectedCaptionID, !edit.captions.contains(where: { $0.id == id }) { selectedCaptionID = nil }
        if let id = reviewedVoiceOverID, !edit.voiceOvers.contains(where: { $0.id == id }) { reviewedVoiceOverID = nil }
        if let id = selectedMusicID, !edit.music.contains(where: { $0.id == id }) { selectedMusicID = nil }
        overlays.editChanged()
        if selectedJoinID != nil, selectedJoinIndex == nil { selectedJoinID = nil }
        // A new treatment isn't what was being compared.
        audio.editChanged()
        // A change is no longer what was being compared; a recording now played is analyzed when it needs to be.
        look.editChanged()
        clips.updateCurveSoundStepping()
        player.show(playedEdit)
        cover.editChanged()
        scheduleDraftSave()
    }

    // MARK: - Panels and picking

    /// Opens `next` under the timeline (nil closes the panel). Leaving a panel ends what went on in it: its undo step, a
    /// narration being recorded, a comparison, Auto measuring, the lines picked in Captions, and Transition's cut.
    func show(_ next: EditorPanel?) {
        guard next != shownPanel else { return }
        leavePanel(for: next, endingChange: true)
    }

    /// Picks `next` (nil lets go). The Text or Audio menu gives way to it; a cut opens its Transition panel; a panel that
    /// works on the picked item closes when it can't work on `next`. Picking never ends an undo step: a gesture that picks
    /// (or lets go of what it removed) keeps its one step.
    func pick(_ next: EditorSelection?) {
        guard next != picked else { return }
        picked = next
        if next != nil { toolMenu = nil }
        if next?.joinID != nil {
            if shownPanel != .transition {
                leavePanel(for: nil, endingChange: true)
                leavePanel(for: .transition, endingChange: true)
            }
        } else if let panel = shownPanel, look.followsSelection(panel), !(next.map { look.accepts($0, in: panel) } ?? false) {
            leavePanel(for: nil, endingChange: false)
        }
    }

    /// The one way the panel changes: what the panel left behind ends, in this order, once.
    private func leavePanel(for next: EditorPanel?, endingChange: Bool) {
        let previous = shownPanel
        guard next != previous else { return }
        shownPanel = next
        showsAdvanced = false
        panelTab = .presets
        audio.panelChanged(from: previous)
        // Auto, Compare, the recordings' analysis for Format and Stabilize, a clip's scope.
        look.panelChanged(to: next)
        if endingChange { endChange() }
        audio.stopRecordingIfNeeded()
        // A cut is picked only while its Transition panel is open.
        if previous == .transition, picked?.joinID != nil { picked = nil }
        clips.panelChanged(to: next)
        captions.panelChanged(to: next)
    }

    // MARK: - Reading

    var videoURL: URL { takes.videoURL(for: take) }

    /// The recording is open and the preview can play.
    var isReady: Bool { source == .ready && player.state != .failed }

    /// "00:04.1": where the playhead is. It reads the player's clock, so only the small views that
    /// show it redraw while the video plays.
    var currentTimeLabel: String {
        DurationText.editor(player.currentTime)
    }

    /// "00:11.0": the edit's length.
    var durationLabel: String {
        DurationText.editor(edit.editedDuration)
    }

    /// "00:04.1 / 00:11.0"
    var timeLabel: String { currentTimeLabel + " / " + durationLabel }

    var canUndo: Bool { document.canUndo && !audio.isRecordingVoiceOver }
    var canRedo: Bool { document.canRedo && !audio.isRecordingVoiceOver }
    var hasUnsavedChanges: Bool { document.hasUnsavedChanges }

    // MARK: - Playback

    func togglePlayback() {
        guard isReady else { return }
        player.togglePlayback()
    }

    /// VoiceOver: moves the playhead by `seconds`.
    func nudgePlayhead(by seconds: TimeInterval) {
        guard isReady else { return }
        player.pause()
        player.seek(to: player.currentTime + seconds)
    }

    /// Try again, under a preview that couldn't be built: the edit is built from scratch.
    func retryPreview() {
        guard source == .ready else { return }
        player.retry()
    }

    /// What the preview plays: the edit (without what a finger is dragging), or while comparing, the take's sound untreated at
    /// the same loudness.
    var playedEdit: TakeEdit {
        let shown = overlays.hidingDraggedOverlay(in: look.comparesPicture ? edit.withoutPictureLook() : edit)
        guard audio.comparesOriginal, let volume = audio.originalVolume else { return shown }
        var played = shown
        played.audioVersion = VoiceProcessing.currentVersion
        played.voiceEnhancement = .off
        played.noiseReduction = .off
        played.volume = volume
        return played
    }

    /// What the preview plays changed (a comparison started or ended): the player shows it again.
    func showPlayedEdit() {
        player.show(playedEdit)
    }

    /// A recording's motion analysis is ready: the preview is drawn again when what it plays reads one.
    func motionAnalysisDidChange() {
        guard source == .ready, EditedComposition.usesMotion(playedEdit) else { return }
        player.redraw()
    }

    /// Cue is in front again: a preview that failed meanwhile (iOS resets its media services in the background) is built
    /// again on its own.
    func becameActive() {
        guard source == .ready, player.state == .failed else { return }
        player.retry()
    }

    // MARK: - Screen

    /// The preview fills the screen (or comes back); what was picked and the open panel are let go.
    func toggleFullScreen() {
        selection = nil
        toolMenu = nil
        panel = nil
        isFullScreen.toggle()
    }

    /// A tap on the preview beside what's laid on the video: lets go of a picked text, caption or
    /// photo.
    func tapOutsideVideo() {
        switch selection {
        case .text, .caption, .media: selection = nil
        default: break
        }
    }

    // MARK: - Undo

    func undo() {
        guard canUndo, document.undo() else { return }
        // Edit by text picks words by their place in the list, which an undone cut changes.
        clips.transcriptSelection = nil
        // VoiceOver hears it happen, as a sighted creator sees the edit change.
        AccessibilityNotification.Announcement(String(localized: "Undone")).post()
    }

    func redo() {
        guard canRedo, document.redo() else { return }
        clips.transcriptSelection = nil
        AccessibilityNotification.Announcement(String(localized: "Redone")).post()
    }

    /// Old takes use a matching version only; a newer script is never an alignment reference.
    var captionScript: Script? { take.captionScript(current: library.script(id: take.scriptID)) }

    // MARK: - Leaving

    /// Saves the edit on the take (its new length, marked Edited) when anything changed.
    func done() {
        endChange()
        audio.stopRecordingIfNeeded()
        // Reversed videos nothing plays any more (a clip reversed and put back) were kept for undo; they go now.
        var saved = edit
        let played = Set(edit.timeline.segments.compactMap(\.sourceID))
        saved.sources.removeAll { $0.reversal != nil && !played.contains($0.id) }
        if source == .ready, hasUnsavedChanges {
            do {
                try takes.applyEdit(saved, to: take.id)
            } catch {
                noteFailure(error, "save")
                // Not on disk: the edit stays a draft (and its files with it) that Edit opens again, or, when even that
                // can't be written, the creator hears it wasn't saved.
                let kept = saveDraft(forced: true)
                close(keepingDraft: true)
                toast.show(kept ? String(localized: "Couldn't save the edits · Kept as a draft") : Self.notSaved)
                return
            }
            toast.show(String(localized: "Edits saved to this take"))
        }
        removeUnusedImports(keeping: saved.mediaFileNames)
        close(keepingDraft: false)
    }

    /// The edit couldn't be written anywhere: a full iPhone is the likely reason.
    private static var notSaved: String { String(localized: "Couldn't save the edits · Free up space on this iPhone") }

    /// Done: pauses and asks "Is it ready to post?" (`EditorDoneSheet`); the answer is `finish(_:)`.
    func askIfReadyToPost() {
        guard isReady else { return }
        endChange()
        player.pause()
        selection = nil
        panel = nil
        sheet = .done
    }

    /// Leaves the editor the way the creator answered: the edit is saved on the take (share, download,
    /// ready later), kept as a draft the video stays in edit with (not yet), or kept as a draft
    /// without asking (back).
    func finish(_ outcome: EditorOutcome) {
        sheet = nil
        switch outcome {
        case .share, .download, .ready: done()
        case .notYet: keepForLater()
        case .back: cancel()
        }
    }

    /// "Not yet, I'll come back": the draft stays even if nothing changed, so the video is in edit.
    private func keepForLater() {
        endChange()
        // A narration being recorded is kept with the draft.
        audio.stopRecordingIfNeeded()
        let kept = saveDraft(forced: true)
        close(keepingDraft: true)
        if !kept { toast.show(Self.notSaved) }
    }

    /// Leaves without saving on the take. Changes stay in a draft that Edit picks up again; the take
    /// is as it was.
    func cancel() {
        endChange()
        // A narration being recorded is kept with the draft, like every other change.
        audio.stopRecordingIfNeeded()
        guard source == .ready, hasUnsavedChanges else {
            removeUnusedImports(keeping: document.original.mediaFileNames)
            close(keepingDraft: false)
            return
        }
        let kept = saveDraft()
        close(keepingDraft: true)
        toast.show(kept ? String(localized: "Draft saved") : Self.notSaved)
    }

    /// Leaving the app or the screen without Done or Cancel: the draft keeps everything.
    func pauseAndKeepDraft() {
        audio.stopRecordingIfNeeded()
        player.pause()
        saveDraft()
    }

    /// Files copied in during this visit that nothing kept names: the take's saved edit (and the
    /// one it had) still point at theirs.
    private func removeUnusedImports(keeping names: Set<String>) {
        let unused = importedFiles.subtracting(names).subtracting(document.original.mediaFileNames)
        importedFiles = []
        EditMediaFiles.remove(unused)
    }

    /// Nothing started here outlives the editor: every job is cancelled, and what a slow one hands back after is dropped
    /// (its ticket is no longer current; work awaited elsewhere checks `isClosed`).
    private func close(keepingDraft: Bool) {
        look.cancelAuto()
        overlays.trackingProgress = nil
        jobs.close()
        captions.translationRequest = nil
        if !keepingDraft { drafts.discard(takeID: take.id) }
        player.stop()
    }

    /// Writes down a failure the creator was told about (`EditorFailureReport`): what was being done, the error and the
    /// edit's size. A cancellation isn't one.
    func noteFailure(_ error: any Error, _ operation: String) {
        guard let report = EditorFailureReport.make(error, operation: operation, edit: edit) else { return }
        reportFailure(report)
    }

    /// Starts work a tool waits for (a freeze frame, a reverse, a sound pulled out): leaving the editor cancels it.
    func startJob(_ work: @escaping @MainActor () async -> Void) {
        jobs.startTool(work)
    }

    // MARK: - Draft

    private func scheduleDraftSave() {
        jobs.start(.draft) { [weak self] _ in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.autosaveDraft()
        }
    }

    /// 600 ms after a change: the draft written off the main thread (`QuickEditDraftStoring.saveSoon`), or dropped when
    /// nothing is changed any more.
    private func autosaveDraft() {
        guard source == .ready, !isClosed else { return }
        if hasUnsavedChanges {
            drafts.saveSoon(QuickEditDraft(takeID: take.id, edit: edit, playhead: player.currentTime, history: document.history, savedAt: .now))
        } else {
            drafts.discard(takeID: take.id)
        }
    }

    /// Keeps the edit, the playhead and the undo steps now (on leaving, or the app going away), or drops the draft when
    /// nothing changed. False when the draft couldn't be written (the store logs why).
    @discardableResult
    func saveDraft(forced: Bool = false) -> Bool {
        guard source == .ready, !isClosed else { return true }
        if hasUnsavedChanges || forced {
            do {
                try drafts.save(QuickEditDraft(takeID: take.id, edit: edit, playhead: player.currentTime, history: document.history, savedAt: .now))
            } catch {
                noteFailure(error, "draft")
                return false
            }
        } else {
            drafts.discard(takeID: take.id)
        }
        return true
    }
}
