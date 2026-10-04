//
//  QuickEditViewModel.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Quick edit of one take. The edit is a recipe (`TakeEdit`) on top of the recording, which is
/// never changed, and the player (`EditPlayback`) plays it and owns the playhead. Timeline changes
/// (trim, remove part, cut, delete, speed, transitions, Clean Up, Remove Pauses) are undoable,
/// together with what was decided about Clean Up's suggestions, what was added on top (texts,
/// media, voice-overs, cover) and the look a style sets (`EditSnapshot`); Audio and Adjust set the
/// sound and light directly. A gesture or a sheet that changes something many times in a row is
/// one undo step (`beginChange` / `endChange`). A draft is kept while editing and when leaving
/// with Cancel; Done saves the edit on the take.
///
/// Each tool's work is in its own extension (`QuickEditViewModel+Text`, `+Media`, `+VoiceOver`,
/// `+Speed`, `+Pauses`, `+Style`, `+Cover`, `+CleanUp`).
@MainActor
@Observable
final class QuickEditViewModel {
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
    /// live in the preview.
    var panel: EditorPanel? {
        didSet {
            guard panel != oldValue else { return }
            showsAdvanced = false
            panelTab = panel.map(EditorPanelTab.first(for:)) ?? .presets
            if oldValue == .voice { endComparison() }
            // Leaving Adjust (or opening it again) never leaves a measurement running or the picture compared.
            if panel != .adjust { cancelAuto() }
            comparesPicture = false
            endChange()
            // Leaving Pauses without removing them puts them back.
            cancelPausePreview()
            if recorder.isRecording { stopVoiceOver() }
            isPickingCoverFrame = false
            if oldValue == .transition { selectedJoinID = nil }
            if panel == .pauses { cleanUpMarks = [:] }
            if panel == nil { lookScopeIsClip = false }
        }
    }
    /// The one thing picked on the timeline or in the preview; its tools replace the toolbar's.
    var selection: EditorSelection? {
        didSet {
            guard selection != oldValue else { return }
            if selection != nil { toolMenu = nil }
            selectedJoinID = nil
            if let panel, followsSelection(panel), !(selection.map { accepts($0, in: panel) } ?? false) { self.panel = nil }
        }
    }
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
    /// What Text style changes: this text, every text, or every text and the captions.
    var textStyleScope: TextStyleScope = .selected
    /// The Text style panel's field takes the keyboard (a text was just added, or Edit was tapped).
    var focusesTextField = false
    /// The picked caption line's field takes the keyboard (a line was just added).
    var focusesCaptionField = false
    var edit: TakeEdit {
        didSet { editDidChange() }
    }
    private(set) var source: Source = .loading
    private(set) var history = EditHistory<EditSnapshot>()
    /// The clip tapped on the timeline. Separate from the playhead: scrubbing doesn't change it.
    var selectedSegmentID: UUID? {
        get { selection?.clipID }
        set { select(newValue.map(EditorSelection.clip), replacing: \.clipID) }
    }
    /// The cut tapped on the timeline, named by the section that starts there: its transition can
    /// be picked. Never at the same time as a selection.
    var selectedJoinID: UUID? {
        didSet {
            if selectedJoinID == nil, panel == .transition { panel = nil }
        }
    }
    /// The trim handle being dragged.
    var activeHandle: TrimHandle?
    /// Captions listening to the take (see `QuickEditViewModel+Captions`).
    var captionState: CaptionState = .idle
    /// Asking before new captions replace lines the creator corrected or wrote.
    var confirmsCaptionReplacement = false
    /// The caption line open in its sheet.
    var editingCaptionID: UUID?
    /// The Translate sheet is open.
    var showsTranslation = false
    /// Translating the captions (see `QuickEditViewModel+Translation`).
    var translationState: TranslationState = .idle
    /// The translation the view asks the system for; nil when none is wanted.
    var translationRequest: TranslationRequest?
    /// Auto measuring the clip (see `QuickEditViewModel+AutoLook`).
    var autoState: AutoAdjustState = .idle
    /// Adjust › Compare: the preview shows the picture without Auto, Adjust and Filters.
    var comparesPicture = false {
        didSet {
            guard comparesPicture != oldValue else { return }
            player.show(playedEdit)
        }
    }
    @ObservationIgnored var autoTask: Task<Void, Never>?
    /// The measuring whose result is still wanted: an older one finishing late is dropped.
    @ObservationIgnored var autoRequest: UUID?
    @ObservationIgnored var captionTask: Task<Void, Never>?
    /// The captions request whose result is still wanted: an older one finishing late is dropped.
    @ObservationIgnored var captionRequest: UUID?
    /// Frames per second of the recording: read from the file when it opens, the take's setting
    /// until then. The timeline puts every edit on a frame (`FrameGrid`).
    private(set) var frameRate: Double
    /// Clean Up listening to the take (see `QuickEditViewModel+CleanUp`).
    var analysis: Analysis = .idle
    /// "Pauses longer than": shorter pauses aren't listed and stay as natural ones (kept with the
    /// edit).
    var pauseThreshold: TimeInterval {
        get { edit.pauseThreshold }
        set { changeLook(key: "pauseThreshold") { $0.pauseThreshold = newValue } }
    }
    /// Pauses, filler words and retakes marked differently from their default while Pauses is
    /// open (by default pauses and sure words are marked to go).
    var cleanUpMarks: [UUID: Bool] = [:]
    /// The pause or word being listened to in Pauses.
    var listeningID: UUID?
    /// Clean Up's view: the pauses, or the words to review. Switching lets go of a pause preview.
    var cleanUpSection: CleanUpSection = .pauses {
        didSet { if cleanUpSection != oldValue { cancelPausePreview() } }
    }

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
    /// The voice-over picked on its track (or just recorded).
    var reviewedVoiceOverID: UUID? {
        get { selection?.voiceOverID }
        set { select(newValue.map(EditorSelection.voiceOver), replacing: \.voiceOverID) }
    }
    /// Edited seconds where the voice-over being recorded started.
    var recordingStart: TimeInterval?
    /// The cover as drawn, for the preview; nil until drawn or without a cover.
    var coverImage: Data?
    var isDrawingCover = false
    /// Cover: the video shows instead of the cover while another frame is picked.
    var isPickingCoverFrame = false
    /// Remove Pauses: the edit before its preview, while the result plays without the pauses. Apply
    /// keeps it as one undo step; anything else puts it back.
    var pausePreviewBase: EditSnapshot?
    /// Speed: the section under the playhead (or selected), or the whole video.
    var speedScope: SpeedScope = .whole
    /// The type the creator saved as "My style" (see `QuickEditViewModel+Style`).
    var myStyle: TextLook?
    /// The cover style saved as "My cover style".
    var myCoverLook: CoverLook?
    /// The creator's handle, for the cover's "@handle" element (set by the screen).
    var creatorHandle = ""
    /// Cover's preview: the cover as it will be posted, or inside a profile's grid.
    var coverPreview: CoverPreviewMode = .feed

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
    @ObservationIgnored var comparisonTask: Task<Void, Never>?

    let take: Take
    let player: EditPlayback
    let editing: TakeEditing
    let library: ScriptLibraryService
    let toast: ToastService
    let mediaImporter: EditMediaImporting
    let recorder: VoiceOverRecording
    let styles: TextStyleStoring
    let translations: TranslationAvailabilityChecking
    /// The library of takes (a montage adds others from it).
    let takes: TakeLibraryService
    private let drafts: QuickEditDraftStoring
    /// What a script is heard in for captions and Clean Up (`LanguageService.captionRequest(for:)`).
    let speechLanguageFor: (Script?) -> SpeechLanguageRequest
    /// Voice Following's language when it differs from the captions' (`LanguageService.languageConflict(for:)`).
    private let languageConflictFor: (Script?) -> SpeechLanguageConflict?
    /// The take's edit when Quick edit opened.
    private var original: TakeEdit
    /// The timeline when a handle drag started. Every move of the drag starts again from it, so a
    /// handle dragged past a cut and back brings the cut back, and the whole drag is one undo step.
    /// The timeline strip keeps drawing it until the finger lifts, so nothing shifts under it.
    var trimOrigin: EditTimeline?
    /// The undo step a gesture or a sheet started from (see `beginChange`).
    @ObservationIgnored private(set) var changeBase: EditSnapshot?
    /// Media files copied in while Quick edit is open, so what the edit doesn't keep is removed.
    @ObservationIgnored var importedFiles: Set<String> = []
    @ObservationIgnored var coverTask: Task<Void, Never>?
    /// A short part playing to show a change (a zoom, a reveal, a pause heard).
    @ObservationIgnored var previewTask: Task<Void, Never>?
    @ObservationIgnored private var draftTask: Task<Void, Never>?
    @ObservationIgnored private(set) var isClosed = false

    init(
        take: Take, takes: TakeLibraryService, library: ScriptLibraryService, editing: TakeEditing,
        drafts: QuickEditDraftStoring, toast: ToastService, player: EditPlayback? = nil,
        mediaImporter: EditMediaImporting? = nil, recorder: VoiceOverRecording? = nil, styles: TextStyleStoring? = nil,
        translations: TranslationAvailabilityChecking = AppleTranslationAvailability(),
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest = SpeechLanguageRequest.script,
        languageConflict: @escaping (Script?) -> SpeechLanguageConflict? = { _ in nil }
    ) {
        self.take = take
        languageConflictFor = languageConflict
        self.styles = styles ?? TextStyleStore()
        self.translations = translations
        myStyle = self.styles.myStyle
        myCoverLook = self.styles.myCoverLook
        speechLanguageFor = speechLanguage
        self.mediaImporter = mediaImporter ?? EditMediaImporter()
        self.recorder = recorder ?? VoiceOverRecorder()
        self.takes = takes
        self.library = library
        self.editing = editing
        self.drafts = drafts
        self.toast = toast
        var edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        if take.edit == nil { edit.captionCollection?.safeMargins = Self.captionSafeMargins(for: take, aspect: take.aspect) }
        edit.captions = edit.captions.map(CaptionRevision.withoutContinuation)
        original = edit
        self.edit = edit
        frameRate = Double(take.frameRate.rawValue)
        self.player = player ?? QuickEditPlayer(videoURL: takes.videoURL(for: take), editing: editing)
    }

    /// Opens the recording, picks up a draft left behind and starts the player.
    func prepare() async {
        guard source == .loading else { return }
        let duration: TimeInterval
        do {
            duration = try await editing.sourceDuration(ofVideoAt: videoURL)
        } catch {
            source = .unavailable
            return
        }
        if let rate = await editing.frameRate(ofVideoAt: videoURL) { frameRate = FrameGrid(rate: rate).rate }
        guard !isClosed else { return }
        // The file's own length wins over the take's saved one.
        original.timeline = original.timeline.fitted(toSourceDuration: duration)
        var start = original
        var playhead: TimeInterval = 0
        if let draft = drafts.draft(for: take.id), draft.edit != original {
            start = draft.edit
            start.captions = start.captions.map(CaptionRevision.withoutContinuation)
            start.timeline = start.timeline.fitted(toSourceDuration: duration)
            history = draft.history
            playhead = draft.playhead
            toast.show(String(localized: "Draft restored"))
        }
        edit = start
        if edit.cleanUpAnalyzed { analysis = .done }
        source = .ready
        player.show(edit)
        player.seek(to: playhead)
    }

    private func editDidChange() {
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
        player.show(playedEdit)
        scheduleDraftSave()
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

    /// "Original · 1:04" until something is cut, then "1:04 → 0:58".
    var durationChange: String {
        let source = DurationText.clock(edit.sourceDuration)
        guard abs(edit.sourceDuration - edit.editedDuration) >= 0.05 else {
            return String(localized: "Original · \(source)")
        }
        return source + " → " + DurationText.clock(edit.editedDuration)
    }

    /// "00:04.1": where the playhead is. It reads the player's clock, so only the small views that
    /// show it redraw while the video plays.
    var currentTimeLabel: String {
        DurationText.editor(player.currentTime)
    }

    /// "00:11.0": the edit's length.
    var durationLabel: String {
        DurationText.editor(edit.editedDuration)
    }

    /// The recording's frames in time.
    var frameGrid: FrameGrid { FrameGrid(rate: frameRate) }

    /// The frame nearest to `time` (edited seconds): where a finger on the timeline lands.
    func frameSnapped(edited time: TimeInterval) -> TimeInterval {
        frameGrid.snapped(edited: time, in: edit.timeline)
    }

    /// "00:04.1 / 00:11.0"
    var timeLabel: String { currentTimeLabel + " / " + durationLabel }

    var canUndo: Bool { (history.canUndo || pausePreviewBase != nil) && activeHandle == nil && !recorder.isRecording }
    var canRedo: Bool { history.canRedo && activeHandle == nil && pausePreviewBase == nil && !recorder.isRecording }
    var canDeleteSelection: Bool { selectedSegmentID != nil && edit.timeline.segments.count > 1 }
    var hasUnsavedChanges: Bool { edit != original }

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

    /// Where a handle is in the recording.
    func handleAccessibilityValue(_ handle: TrimHandle) -> String {
        let time = handle == .start ? edit.timeline.trimStart : edit.timeline.trimEnd
        return DurationText.timecode(time, total: edit.sourceDuration)
    }

    // MARK: - Playback

    func togglePlayback() {
        guard isReady else { return }
        player.togglePlayback()
    }

    /// Follows a finger on the timeline; the video stays paused.
    func scrub(to time: TimeInterval) {
        guard isReady else { return }
        player.scrub(to: time)
    }

    func endScrub() {
        player.endScrub()
    }

    /// VoiceOver: moves the playhead by `seconds`.
    func nudgePlayhead(by seconds: TimeInterval) {
        guard isReady else { return }
        player.pause()
        player.seek(to: player.currentTime + seconds)
    }

    // MARK: - Screen

    /// Export: the sheet that makes the video file (Done is what saves the edit on the take).
    func openExport() {
        guard isReady else { return }
        endChange()
        player.pause()
        selection = nil
        panel = nil
        sheet = .export
    }

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

    // MARK: - Selection

    /// A tap on the timeline (the playhead already went there): selects the section under it, or
    /// lets go of it when it was already selected or the tap was beside the sections. Nothing to
    /// select while there is one section.
    func tapTimeline(onPiece index: Int?) {
        clearLayerSelection()
        guard let index, edit.timeline.segments.count > 1, edit.timeline.segments.indices.contains(index) else {
            selectedSegmentID = nil
            selectedJoinID = nil
            return
        }
        let id = edit.timeline.segments[index].id
        selectedJoinID = nil
        selectedSegmentID = selectedSegmentID == id ? nil : id
    }

    func selectPieceAtPlayhead() {
        tapTimeline(onPiece: edit.timeline.segmentIndex(atEdited: player.currentTime))
    }

    // MARK: - Undo

    func undo() {
        guard canUndo else { return }
        // A pauses preview is taken back first, like it was never applied.
        if pausePreviewBase != nil {
            cancelPausePreview()
            return
        }
        endChange()
        guard let previous = history.undo(from: snapshot) else { return }
        restore(previous)
    }

    func redo() {
        guard canRedo else { return }
        endChange()
        guard let next = history.redo(from: snapshot) else { return }
        restore(next)
    }

    /// What undo keeps of the edit: the timeline, the suggestions' decisions, what was added on top
    /// and the look a style sets.
    var snapshot: EditSnapshot {
        EditSnapshot(edit)
    }

    /// A change undo can take back: a new timeline, and new decisions about suggestions.
    func commit(_ timeline: EditTimeline, suggestions: [CleanUpSuggestion]? = nil, key: String? = nil) {
        var next = snapshot
        next.timeline = timeline
        if let suggestions { next.suggestions = suggestions }
        commit(next, key: key)
    }

    /// A change undo can take back. Inside a gesture or a sheet (`beginChange`), the step was
    /// already taken when it began. Changes with the same `key` in a quick row (a slider, typing)
    /// are one step (`EditHistory.coalescingInterval`).
    func commit(_ next: EditSnapshot, key: String? = nil) {
        guard next != snapshot else { return }
        if changeBase == nil { history.record(snapshot, key: key, at: .now) }
        var changed = edit
        Self.apply(next, to: &changed)
        edit = changed
    }

    /// Keeps `step` as the state to go back to, without changing the edit (Remove Pauses' Apply,
    /// after its preview already changed it).
    func recordUndoStep(_ step: EditSnapshot) {
        guard step != snapshot else { return }
        history.record(step)
    }

    /// Changes what undo keeps (texts, media, voice-overs, the cover, the style) as one step;
    /// with a `key`, quick changes of the same kind join one step.
    func change(key: String? = nil, _ update: (inout EditSnapshot) -> Void) {
        var next = snapshot
        update(&next)
        commit(next, key: key)
    }

    /// A gesture or a sheet starts changing something, maybe many times: all of it is one undo
    /// step, taken when it ends (`endChange`).
    func beginChange() {
        guard changeBase == nil else { return }
        changeBase = snapshot
    }

    /// The gesture or sheet is over: one undo step back to where it began, when anything changed.
    func endChange() {
        guard let base = changeBase else { return }
        changeBase = nil
        if base != snapshot { history.record(base) }
    }

    /// Goes back (or forward) to a step. Suggestions found since keep their place and take the
    /// step's decision, or wait for review when the step didn't know them yet.
    func restore(_ step: EditSnapshot) {
        let decisions = Dictionary(step.suggestions.map { ($0.id, $0.status) }, uniquingKeysWith: { first, _ in first })
        var changed = edit
        Self.apply(step, to: &changed)
        changed.suggestions = edit.suggestions.map { suggestion in
            var restored = suggestion
            restored.status = decisions[suggestion.id] ?? .pending
            return restored
        }
        edit = changed
    }

    /// Everything undo keeps, set on `edit`.
    private static func apply(_ step: EditSnapshot, to edit: inout TakeEdit) {
        edit.timeline = step.timeline
        edit.suggestions = step.suggestions
        edit.texts = step.texts
        edit.media = step.media
        edit.voiceOvers = step.voiceOvers
        edit.cover = step.cover
        edit.creatorStyle = step.creatorStyle
        edit.captionStyle = step.captionStyle
        edit.filter = step.filter
        edit.textLook = step.textLook
        edit.textPreset = step.textPreset
        edit.captionLook = step.captionLook
        edit.captionPreset = step.captionPreset
        if step.captionCollectionVersion != nil { edit.captionCollection = step.captionCollection }
        if let position = step.captionPosition { edit.captionPosition = position }
        if let captions = step.captions { edit.captions = captions }
        if let sources = step.sources { edit.sources = sources }
        if let animation = step.captionAnimation { edit.captionAnimation = animation }
        if let translations = step.captionTranslations { edit.captionTranslations = translations }
        if let display = step.captionDisplay { edit.captionDisplay = display }
        if let music = step.music { edit.music = music }
        if let backgrounds = step.backgrounds { edit.backgrounds = backgrounds }
        step.look?.apply(to: &edit)
    }

    /// The take's script, or nothing for a freestyle take.
    var scriptText: String {
        captionScript?.text ?? ""
    }

    /// Old takes use a matching version only; a newer script is never an alignment reference.
    var captionScript: Script? { take.captionScript(current: library.script(id: take.scriptID)) }

    /// The language the take is heard in, for captions and Clean Up: the script's (never Voice
    /// Following's or the interface's).
    var speechLanguage: SpeechLanguageRequest {
        speechLanguageFor(captionScript)
    }

    /// Said under Captions while they listen in the script's language (Automatic) and Voice
    /// Following listens in another one, so the two never disagree silently.
    var captionLanguageConflict: SpeechLanguageConflict? {
        guard edit.captionLanguage == nil else { return nil }
        return languageConflictFor(captionScript)
    }

    // MARK: - Leaving

    /// Saves the edit on the take (its new length, marked Edited) when anything changed.
    func done() {
        endTrim()
        endChange()
        if recorder.isRecording { stopVoiceOver() }
        // Done while the pauses preview plays keeps what was heard.
        if pausePreviewBase != nil { applyPauses() }
        if source == .ready, hasUnsavedChanges {
            takes.applyEdit(edit, to: take.id)
            toast.show(String(localized: "Edits saved to this take"))
        }
        removeUnusedImports(keeping: edit.mediaFileNames)
        close(keepingDraft: false)
    }

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
        endTrim()
        endChange()
        if recorder.isRecording { cancelVoiceOver() }
        cancelPausePreview()
        saveDraft(forced: true)
        close(keepingDraft: true)
    }

    /// Leaves without saving on the take. Changes stay in a draft that Edit picks up again; the take
    /// is as it was.
    func cancel() {
        endTrim()
        endChange()
        if recorder.isRecording { cancelVoiceOver() }
        cancelPausePreview()
        guard source == .ready, hasUnsavedChanges else {
            removeUnusedImports(keeping: original.mediaFileNames)
            close(keepingDraft: false)
            return
        }
        saveDraft()
        close(keepingDraft: true)
        toast.show(String(localized: "Draft kept · Tap Edit"))
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
        let unused = importedFiles.subtracting(names).subtracting(original.mediaFileNames)
        importedFiles = []
        EditMediaFiles.remove(unused)
    }

    private func close(keepingDraft: Bool) {
        isClosed = true
        draftTask?.cancel()
        coverTask?.cancel()
        captionTask?.cancel()
        captionRequest = nil
        cancelAuto()
        if !keepingDraft { drafts.discard(takeID: take.id) }
        player.stop()
    }

    // MARK: - Draft

    private func scheduleDraftSave() {
        guard !isClosed else { return }
        draftTask?.cancel()
        draftTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveDraft()
        }
    }

    /// Keeps the edit, the playhead and the undo steps, or drops the draft when nothing changed.
    func saveDraft(forced: Bool = false) {
        guard source == .ready, !isClosed else { return }
        // A pauses preview that wasn't applied isn't part of the edit.
        var kept = edit
        if let base = pausePreviewBase { Self.apply(base, to: &kept) }
        if kept != original || forced {
            drafts.save(QuickEditDraft(takeID: take.id, edit: kept, playhead: player.currentTime, history: history, savedAt: .now))
        } else {
            drafts.discard(takeID: take.id)
        }
    }
}
