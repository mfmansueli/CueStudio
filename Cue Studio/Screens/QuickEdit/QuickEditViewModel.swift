//
//  QuickEditViewModel.swift
//  Cue Studio
//

import Accessibility
import CoreGraphics
import Foundation

/// Quick edit of one take. The edit is a recipe (`TakeEdit`) on top of the recording, which is
/// never changed, and the player (`EditPlayback`) plays it and owns the playhead. Timeline changes
/// (trim, split, delete, speed, transitions, Pauses) are undoable,
/// together with what was decided about Clean Up's suggestions, what was added on top (texts,
/// media, voice-overs, cover) and the look a style sets (`EditSnapshot`); Audio and Adjust set the
/// sound and light directly. A gesture or a sheet that changes something many times in a row is
/// one undo step (`beginChange` / `endChange`). A draft is kept while editing and when leaving
/// with Cancel; Done saves the edit on the take.
///
/// The editor coordinates its parts (`EditorPart`: `CaptionsViewModel`, `CoverViewModel`), each with its own state, working on the edit
/// through the session (`EditorSession`) the editor hosts (`EditorHost`): it wires what one part's change means for another
/// (a panel left, the edit changed, the editor closed). The tools not in a part yet are in their own extensions
/// (`QuickEditViewModel+Text`, `+Media`, `+VoiceOver`, `+ClipSettings`, `+PausesPanel`, `+Style`, `+CleanUp`).
@MainActor
@Observable
final class QuickEditViewModel: EditorHost, EditorPart {
    /// Whether the recording could be opened.
    enum Source: Equatable {
        case loading, ready, unavailable
    }

    /// Clean Up listening to the take.
    enum Analysis: Equatable {
        case idle, running, done, failed
    }

    /// How long before a cut the playhead waits after a transition is picked, so Play shows it.
    static let transitionLeadIn: TimeInterval = 1

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
            // "Replace" asks for the file only for the sheet it opened.
            if sheet != .music { musicReplacementID = nil }
        }
    }
    /// The music clip the next sound file replaces ("Replace"); nil adds a new clip.
    var musicReplacementID: UUID?
    /// Where "Add photo or video" puts what is picked.
    var mediaInsertMode: MediaInsertMode = .overlay
    /// The timeline's zoom (44 points per second at 1), from 0.35 to 5.
    var timelineZoom: CGFloat = 1
    /// The timeline handle being dragged.
    var handleDrag: TimelineHandleDrag?
    /// Where the dragged handle last stuck, so the haptic plays once per snap.
    @ObservationIgnored var lastHandleSnap: TimeInterval?
    /// What Text style's look changes: this text or every text. The words, timing and motion are
    /// always the picked text's.
    var textStyleScope: TextStyleScope = .selected
    /// The styling panels (Text style, Caption style) are expanded: the video gets as small as it
    /// ever gets so the controls have room. Kept while the editor is open.
    var stylePanelIsExpanded = false
    /// The Text style panel's field takes the keyboard (a text was just added, or Edit was tapped).
    var focusesTextField = false
    /// The edit and its undo steps (`EditDocument`): the edit changes only there, and this hears each change.
    let document: EditDocument
    private(set) var source: Source = .loading
    /// The clip tapped on the timeline. Separate from the playhead: scrubbing doesn't change it.
    var selectedSegmentID: UUID? {
        get { selection?.clipID }
        set { select(newValue.map(EditorSelection.clip), replacing: \.clipID) }
    }
    /// The cut tapped on the timeline, named by the section that starts there: its transition can
    /// be picked (`EditorSelection.join`).
    var selectedJoinID: UUID? {
        get { selection?.joinID }
        set { select(newValue.map(EditorSelection.join), replacing: \.joinID) }
    }
    /// The setting Adjust opens on, once (`open(_:)`); nil opens where it always does.
    var adjustOpensOn: Adjustment?
    /// Auto measuring the clip (see `QuickEditViewModel+AutoLook`).
    var autoState: AutoAdjustState = .idle
    /// The text or photo or video a finger is moving on the preview: the video leaves it out meanwhile
    /// (`hidingDraggedOverlay(in:)`).
    var draggedOverlay: EditorSelection?
    /// Adjust › Compare: the preview shows the picture without Auto, Adjust and Filters.
    var comparesPicture = false {
        didSet {
            guard comparesPicture != oldValue else { return }
            player.show(playedEdit)
        }
    }
    /// Frames per second of the recording: read from the file when it opens, the take's setting
    /// until then. The timeline puts every edit on a frame (`FrameGrid`).
    private(set) var frameRate: Double
    /// Clean Up listening to the take (see `QuickEditViewModel+CleanUp`).
    var analysis: Analysis = .idle
    /// "Pauses longer than": shorter pauses aren't listed and stay as natural ones (kept with the
    /// edit).
    var pauseThreshold: TimeInterval {
        get { edit.pauseThreshold }
        set { changeEdit(key: "pauseThreshold") { $0.pauseThreshold = newValue } }
    }
    /// Pauses, filler words and retakes marked differently from their default while Pauses is
    /// open (by default pauses and sure words are marked to go).
    var cleanUpMarks: [UUID: Bool] = [:]
    /// The pause or word being listened to in Pauses.
    var listeningID: UUID?

    // MARK: Added on top
    /// The text picked on the preview or its track.
    var selectedTextID: UUID? {
        get { selection?.textID }
        set { select(newValue.map(EditorSelection.text), replacing: \.textID) }
    }
    /// The text being written in its sheet.
    var editingTextID: UUID?
    /// The photo or video picked on the preview or its track.
    var selectedMediaID: UUID? {
        get { selection?.mediaID }
        set { select(newValue.map(EditorSelection.media), replacing: \.mediaID) }
    }
    /// The caption line picked on the timeline or in the Captions list.
    var selectedCaptionID: UUID? {
        get { selection?.captionID }
        set { select(newValue.map(EditorSelection.caption), replacing: \.captionID) }
    }
    var isImportingMedia = false
    /// A reverse or an import the creator waits for, over the preview with Cancel (`QuickEditViewModel+Work`).
    var work: EditorWork?
    /// The voice-over picked on its track (or just recorded).
    var reviewedVoiceOverID: UUID? {
        get { selection?.voiceOverID }
        set { select(newValue.map(EditorSelection.voiceOver), replacing: \.voiceOverID) }
    }
    /// Edited seconds where the voice-over being recorded started.
    var recordingStart: TimeInterval?
    /// Voice-over's "Show script": the take's script over the preview while a narration records, remembered for every take
    /// (`QuickEditViewModel+NarrationScript`).
    var showsNarrationScript: Bool {
        didSet { editorPreferences.showsNarrationScript = showsNarrationScript }
    }
    /// The Low Power Mode notice over the preview (`QuickEditViewModel+LowPower`).
    var showsLowPowerNotice = false
    /// How far that script has been read, at a steady pace from the start of the recording.
    var narrationPace: NarrationScriptPace
    /// "Copy look": what a clip's look was when copied; nil until one is.
    var copiedLook: CopiedClipLook?
    /// "Paste look": which parts go, and whether its sheet is open.
    var pastesLookParts: Set<ClipLookPart> = Set(ClipLookPart.allCases)
    var showsPasteLook = false
    /// Edit by text: the picked words (indices in `transcriptWords`).
    var transcriptSelection: ClosedRange<Int>?
    /// The type the creator saved as "My style" (see `QuickEditViewModel+Style`).
    var myStyle: TextLook?
    /// The creator's handle, for the "@handle" graphic and the cover's series (set by the screen).
    var creatorHandle: String {
        get { session.creatorHandle }
        set { session.creatorHandle = newValue }
    }
    /// The beats found in the music files, by file (`QuickEditViewModel+Beats`); bumped `beatsFound` when one comes in.
    @ObservationIgnored var beatCache: [String: BeatTracker.Result] = [:]
    @ObservationIgnored var findingBeats: Set<String> = []
    var beatsFound = 0
    /// Beats › Cut on: every beat, every second or every fourth.
    var beatCutEvery = 2
    /// Speed shows its Curve tab (`QuickEditViewModel+SpeedCurve`).
    var showsSpeedCurves = false
    /// Track: how far following the picked item's object is, 0 to 1; nil when it isn't (`QuickEditViewModel+Track`).
    var trackingProgress: Double?
    /// The recordings whose motion analysis was last asked for while the edit used it (`requestMotionAnalysisIfNeeded`).
    @ObservationIgnored var motionRequestedURLs: [URL] = []
    /// The take's upright frame in pixels, read when the recording opens (Follow face needs a format other than it).
    @ObservationIgnored var recordingUprightSize: CGSize?
    /// A point of the speed curve is being dragged (`QuickEditViewModel+SpeedCurve`).
    @ObservationIgnored var shapesCurve = false

    // MARK: Background
    /// Whether this iPhone can find people in video; nil until checked.
    var canFindPeople: Bool?
    var isImportingBackground = false
    /// Why the photo library is open, if it is (`EditorPhotoPicker`).
    var photoRequest: PhotoRequest?
    /// Adjust, Filters or Background was opened from a picked clip: it changes that clip only, and
    /// follows the picked clip. Opened from the main toolbar it changes the whole take.
    var lookScopeIsClip = false

    // MARK: Sound
    /// The music clip picked on its track.
    var selectedMusicID: UUID? {
        get { selection?.musicID }
        set { select(newValue.map(EditorSelection.music), replacing: \.musicID) }
    }
    var isImportingMusic = false
    /// A video just added that has its own sound: Media asks whether to keep it.
    var soundChoiceMediaID: UUID?
    /// "Compare with original": the preview plays the take's untreated sound at `originalVolume`,
    /// as loud as the treated one.
    var comparesOriginal = false
    var originalVolume: Double?
    /// The treatment being compared; changing it ends the comparison.
    @ObservationIgnored var comparedProcessing: VoiceProcessing?

    let take: Take
    let player: EditPlayback
    let editing: TakeEditing
    let library: ScriptLibraryService
    let toast: ToastService
    let mediaImporter: EditMediaImporting
    let recorder: VoiceOverRecording
    let styles: TextStyleStoring
    /// Quick edit's own switches, kept between edits.
    let editorPreferences: EditorPreferencesStoring
    /// How the creator's teleprompter draws a script (font, colour, spacing, speed): the script shown while a narration records
    /// is drawn the same way.
    let prompterLook: PrompterSettings
    /// Hears a sound effect before it's added.
    let soundPreviews: SoundEffectPreviewing
    /// The library of takes (a montage adds others from it).
    let takes: TakeLibraryService
    /// Analyzes the recordings' motion for Follow face and Stabilize (`QuickEditViewModel+MotionAnalysis`); nil in tests that
    /// don't use it.
    let motion: MotionAnalysisService?
    /// Follows an object through a recording for Track.
    let tracker: ObjectTracking
    private let drafts: QuickEditDraftStoring
    /// What a script is heard in for captions and Clean Up (`LanguageService.captionRequest(for:)`).
    let speechLanguageFor: (Script?) -> SpeechLanguageRequest
    /// What the editor's parts work through: the document, the player, the jobs and the toasts, and this editor as their host.
    let session: EditorSession
    /// Captions: made, corrected, picked, styled, translated and moved on the preview (`CaptionsViewModel`).
    let captions: CaptionsViewModel
    /// The cover: Cover Studio over the editor, and the cover drawn for the timeline's block (`CoverViewModel`).
    let cover: CoverViewModel
    /// Opens Cue's page in the Settings app (a toast's "Settings" when the microphone is off for Cue); tests count it.
    @ObservationIgnored var opensSettings: @MainActor () -> Void = { AppSettingsLink.open() }
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
        self.styles = styles ?? TextStyleStore()
        myStyle = self.styles.myStyle
        let preferences = editorPreferences ?? EditorPreferencesStore()
        self.editorPreferences = preferences
        self.prompterLook = prompterLook
        showsNarrationScript = preferences.showsNarrationScript
        narrationPace = NarrationScriptPace(speed: preferences.narrationScriptSpeed ?? prompterLook.speed)
        self.soundPreviews = soundPreviews ?? SoundEffectPreviewPlayer()
        speechLanguageFor = speechLanguage
        self.mediaImporter = mediaImporter ?? EditMediaImporter()
        self.recorder = recorder ?? VoiceOverRecorder()
        self.takes = takes
        self.motion = motion
        self.tracker = tracker
        self.library = library
        self.editing = editing
        self.drafts = drafts
        self.toast = toast
        var edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        if take.edit == nil { edit.captionCollection?.safeMargins = CaptionsViewModel.captionSafeMargins(for: take, aspect: take.aspect) }
        edit.captions = edit.captions.map(CaptionRevision.withoutContinuation)
        document = EditDocument(edit)
        frameRate = Double(take.frameRate.rawValue)
        let player = player ?? QuickEditPlayer(videoURL: takes.videoURL(for: take), editing: editing)
        self.player = player
        let jobs = EditorJobs()
        self.jobs = jobs
        session = EditorSession(document: document, player: player, jobs: jobs, toast: toast, take: take, videoURL: takes.videoURL(for: take))
        captions = CaptionsViewModel(
            session: session, editing: editing, takes: takes, library: library, styles: self.styles, translations: translations,
            speechLanguage: speechLanguage, likelySpokenLanguages: likelySpokenLanguages, languageConflict: languageConflict
        )
        cover = CoverViewModel(
            session: session, editing: editing, pictures: coverPictures ?? CoverPictureService(), importer: self.mediaImporter,
            styles: self.styles
        )
        session.host = self
        self.recorder.stoppedByItself = { [weak self] reason in self?.voiceOverStoppedByItself(reason) }
        self.player.playingStopped = { [weak self] in self?.playingStopped() }
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
        if let rate = await editing.frameRate(ofVideoAt: videoURL) { frameRate = FrameGrid(rate: rate).rate }
        recordingUprightSize = await EditFraming.shape(of: videoURL)?.uprightSize
        guard !isClosed else { return }
        // The file's own length wins over the take's saved one; a draft left behind comes back with its undo steps.
        var playhead: TimeInterval = 0
        let draft = drafts.draft(for: take.id)
        if document.open(sourceDuration: duration, draft: draft), let draft {
            playhead = draft.playhead
            toast.show(String(localized: "Draft restored"))
        }
        if edit.cleanUpAnalyzed, edit.recordingsToCleanUp.isEmpty { analysis = .done }
        source = .ready
        player.show(edit)
        player.seek(to: playhead)
        cover.drawCover()
        // Only an edit that uses Follow face or Stabilize has its recordings analyzed now; the others when Format or
        // Stabilize opens (an hour of video is a lot to analyze for nothing).
        requestMotionAnalysisIfNeeded()
        findBeatsIfNeeded()
    }

    /// The edit changed: what was picked and is gone is let go, and the preview, the draft and the cover follow.
    private func editChanged(from previous: TakeEdit) {
        // Edit by text picks words by their place in the list, which any change of the cuts moves (the sheet lets the
        // timeline be used behind it).
        if previous.timeline != edit.timeline { transcriptSelection = nil }
        captions.editChanged(from: previous)
        guard source == .ready else { return }
        if let id = selectedSegmentID, edit.timeline.segment(id: id) == nil { selectedSegmentID = nil }
        if let id = selectedTextID, !edit.texts.contains(where: { $0.id == id }) { selectedTextID = nil }
        if let id = selectedMediaID, !edit.media.contains(where: { $0.id == id }) { selectedMediaID = nil }
        if let id = selectedCaptionID, !edit.captions.contains(where: { $0.id == id }) { selectedCaptionID = nil }
        if let id = reviewedVoiceOverID, !edit.voiceOvers.contains(where: { $0.id == id }) { reviewedVoiceOverID = nil }
        if let id = selectedMusicID, !edit.music.contains(where: { $0.id == id }) { selectedMusicID = nil }
        if let id = soundChoiceMediaID, !edit.media.contains(where: { $0.id == id }) { soundChoiceMediaID = nil }
        if selectedJoinID != nil, selectedJoinIndex == nil { selectedJoinID = nil }
        // A new treatment isn't what was being compared.
        if comparesOriginal, edit.voiceProcessing != comparedProcessing { endComparison() }
        // A change is no longer what was being compared.
        if comparesPicture { comparesPicture = false }
        updateCurveSoundStepping()
        player.show(playedEdit)
        requestMotionAnalysisIfNeeded()
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
        } else if let panel = shownPanel, followsSelection(panel), !(next.map { accepts($0, in: panel) } ?? false) {
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
        if previous == .voice { endComparison() }
        // Leaving Adjust (or opening it again) never leaves a measurement running or the picture compared.
        if next != .adjust { cancelAuto() }
        comparesPicture = false
        if endingChange { endChange() }
        if recorder.isRecording { stopVoiceOver() }
        // A cut is picked only while its Transition panel is open.
        if previous == .transition, picked?.joinID != nil { picked = nil }
        if next == .crop || next == .stabilize { requestMotionAnalysis() }
        if next == .pauses {
            cleanUpMarks = [:]
            // Not tied to the panel: leaving Pauses doesn't stop it listening.
            listenForCleanUp()
        }
        if next == nil { lookScopeIsClip = false }
        captions.panelChanged(to: next)
    }

    /// Sets the selection from one of the per-kind ids: a new id selects that item, and nil lets
    /// go only if the selection is of that kind.
    private func select(_ new: EditorSelection?, replacing id: KeyPath<EditorSelection, UUID?>) {
        if let new {
            selection = new
        } else if selection?[keyPath: id] != nil {
            selection = nil
        }
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

    var canUndo: Bool { document.canUndo && !recorder.isRecording }
    var canRedo: Bool { document.canRedo && !recorder.isRecording }
    var hasUnsavedChanges: Bool { document.hasUnsavedChanges }

    var selectedSegmentIndex: Int? {
        selectedSegmentID.flatMap { edit.timeline.index(ofSegment: $0) }
    }

    /// Where the selected cut is: the index of the section that starts there (never the first).
    var selectedJoinIndex: Int? {
        guard let index = selectedJoinID.flatMap({ edit.timeline.index(ofSegment: $0) }), index > 0 else { return nil }
        return index
    }

    /// The selected cut's transition, or nil when no cut is selected.
    var selectedTransition: EditTransition? {
        selectedJoinIndex.map { edit.timeline.transition(atJoin: $0) }
    }

    /// "Clip 2 of 3, 4.2 seconds, playhead at 00:07.1": what VoiceOver reads on the timeline.
    var timelineAccessibilityValue: String {
        let timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: player.currentTime)
        let length = DurationText.tenths(timeline.segments[index].duration)
        var value = String(localized: "Clip \(index + 1) of \(timeline.segments.count), \(length), playhead at \(currentTimeLabel)")
        if selectedSegmentIndex == index { value += ", " + String(localized: "selected") }
        return value
    }

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
        transcriptSelection = nil
        // VoiceOver hears it happen, as a sighted creator sees the edit change.
        AccessibilityNotification.Announcement(String(localized: "Undone")).post()
    }

    func redo() {
        guard canRedo, document.redo() else { return }
        transcriptSelection = nil
        AccessibilityNotification.Announcement(String(localized: "Redone")).post()
    }

    /// Old takes use a matching version only; a newer script is never an alignment reference.
    var captionScript: Script? { take.captionScript(current: library.script(id: take.scriptID)) }

    /// The language the take is heard in, for captions and Clean Up: the script's (never Voice
    /// Following's or the interface's).
    var speechLanguage: SpeechLanguageRequest {
        speechLanguageFor(captionScript)
    }

    // MARK: - Leaving

    /// Saves the edit on the take (its new length, marked Edited) when anything changed.
    func done() {
        endChange()
        if recorder.isRecording { stopVoiceOver() }
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
        if recorder.isRecording { stopVoiceOver() }
        let kept = saveDraft(forced: true)
        close(keepingDraft: true)
        if !kept { toast.show(Self.notSaved) }
    }

    /// Leaves without saving on the take. Changes stay in a draft that Edit picks up again; the take
    /// is as it was.
    func cancel() {
        endChange()
        // A narration being recorded is kept with the draft, like every other change.
        if recorder.isRecording { stopVoiceOver() }
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
        if recorder.isRecording { stopVoiceOver() }
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
        cancelAuto()
        trackingProgress = nil
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
