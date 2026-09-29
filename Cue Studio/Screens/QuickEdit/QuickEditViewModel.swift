//
//  QuickEditViewModel.swift
//  Cue Studio
//

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

    /// Shortest part "Remove part" can mark.
    static let minimumRemoval: TimeInterval = 0.2
    /// Length of the red range when "Remove part" starts.
    static let initialRemoval: TimeInterval = 2
    /// How long before a cut the playhead waits after a transition is picked, so Play shows it.
    static let transitionLeadIn: TimeInterval = 1

    var tool: QuickEditTool = .trim {
        didSet {
            guard tool != oldValue else { return }
            removalRange = nil
            selectedSegmentID = nil
            selectedJoinID = nil
            selectedTextID = nil
            selectedMediaID = nil
            endChange()
            // Leaving Remove Pauses without Apply puts the pauses back.
            cancelPausePreview()
            if recorder.isRecording { stopVoiceOver() }
            isPickingCoverFrame = false
            lastTool[tool.category] = tool
        }
    }
    /// The tool each category opens on: the one used last.
    private(set) var lastTool: [QuickEditCategory: QuickEditTool] = [:]
    var edit: TakeEdit {
        didSet { editDidChange() }
    }
    private(set) var source: Source = .loading
    private(set) var history = EditHistory<EditSnapshot>()
    /// The section tapped on the timeline. Separate from the playhead: scrubbing doesn't change it.
    private(set) var selectedSegmentID: UUID?
    /// The cut tapped on the timeline, named by the section that starts there: its transition can
    /// be picked. Never at the same time as a selected section.
    private(set) var selectedJoinID: UUID?
    /// The trim handle being dragged.
    private(set) var activeHandle: TrimHandle?
    /// "Remove part": the red range, in edited seconds, while it is being placed. Playing from
    /// inside it stops at its end, to watch exactly what would go.
    private(set) var removalRange: ClosedRange<TimeInterval>? {
        didSet { player.reviewedPart = removalRange }
    }
    /// Captions listening to the take (see `QuickEditViewModel+Captions`).
    var captionState: CaptionState = .idle
    /// Asking before new captions replace lines the creator corrected or wrote.
    var confirmsCaptionReplacement = false
    /// The caption line open in its sheet.
    var editingCaptionID: UUID?
    @ObservationIgnored var captionTask: Task<Void, Never>?
    /// The captions request whose result is still wanted: an older one finishing late is dropped.
    @ObservationIgnored var captionRequest: UUID?
    /// Frames per second of the recording: read from the file when it opens, the take's setting
    /// until then. The timeline puts every edit on a frame (`FrameGrid`).
    private(set) var frameRate: Double
    /// The timeline is zoomed in: the clock keeps the hundredths even on a long take.
    var showsPreciseTime = false
    /// Clean Up listening to the take (see `QuickEditViewModel+CleanUp`).
    var analysis: Analysis = .idle
    /// Clean Up's "Ignore pauses under": shorter pauses aren't listed and stay as natural ones.
    var pauseThreshold: TimeInterval = QuickEditViewModel.defaultPauseThreshold

    // MARK: Added on top
    /// The text picked on the preview or its track.
    var selectedTextID: UUID?
    /// The text being written in its sheet.
    var editingTextID: UUID?
    /// The photo or video picked on the preview or its track.
    var selectedMediaID: UUID?
    var isImportingMedia = false
    /// The voice-over just recorded, waiting for Keep (or Redo / Delete).
    var reviewedVoiceOverID: UUID?
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

    let take: Take
    let player: EditPlayback
    let editing: TakeEditing
    let library: ScriptLibraryService
    let toast: ToastService
    let mediaImporter: EditMediaImporting
    let recorder: VoiceOverRecording
    let styles: TextStyleStoring
    private let takes: TakeLibraryService
    private let drafts: QuickEditDraftStoring
    /// What a script is heard in (`LanguageService.speechRequest(for:)`).
    private let speechLanguageFor: (Script?) -> SpeechLanguageRequest
    /// The take's edit when Quick edit opened.
    private var original: TakeEdit
    /// The timeline when a handle drag started. Every move of the drag starts again from it, so a
    /// handle dragged past a cut and back brings the cut back, and the whole drag is one undo step.
    /// The timeline strip keeps drawing it until the finger lifts, so nothing shifts under it.
    private(set) var trimOrigin: EditTimeline?
    /// The undo step a gesture or a sheet started from (see `beginChange`).
    @ObservationIgnored private(set) var changeBase: EditSnapshot?
    /// Media files copied in while Quick edit is open, so what the edit doesn't keep is removed.
    @ObservationIgnored var importedFiles: Set<String> = []
    @ObservationIgnored var coverTask: Task<Void, Never>?
    @ObservationIgnored private var draftTask: Task<Void, Never>?
    @ObservationIgnored private(set) var isClosed = false

    init(
        take: Take, takes: TakeLibraryService, library: ScriptLibraryService, editing: TakeEditing,
        drafts: QuickEditDraftStoring, toast: ToastService, player: EditPlayback? = nil,
        mediaImporter: EditMediaImporting? = nil, recorder: VoiceOverRecording? = nil, styles: TextStyleStoring? = nil,
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest = SpeechLanguageRequest.script
    ) {
        self.take = take
        self.styles = styles ?? TextStyleStore()
        myStyle = self.styles.myStyle
        speechLanguageFor = speechLanguage
        self.mediaImporter = mediaImporter ?? EditMediaImporter()
        self.recorder = recorder ?? VoiceOverRecorder()
        self.takes = takes
        self.library = library
        self.editing = editing
        self.drafts = drafts
        self.toast = toast
        let edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
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
        if let id = reviewedVoiceOverID, !edit.voiceOvers.contains(where: { $0.id == id }) { reviewedVoiceOverID = nil }
        if selectedJoinID != nil, selectedJoinIndex == nil { selectedJoinID = nil }
        if let range = removalRange, range.upperBound > edit.editedDuration { removalRange = nil }
        player.show(edit)
        scheduleDraftSave()
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

    /// "00:04.32": where the playhead is. It reads the player's clock, so only the small views that
    /// show it redraw while the video plays.
    var currentTimeLabel: String {
        DurationText.timecode(player.currentTime, total: edit.editedDuration, precise: showsPreciseTime)
    }

    /// "00:11.00": the edit's length.
    var durationLabel: String {
        DurationText.timecode(edit.editedDuration, total: edit.editedDuration, precise: showsPreciseTime)
    }

    /// The recording's frames in time.
    var frameGrid: FrameGrid { FrameGrid(rate: frameRate) }

    /// The frame nearest to `time` (edited seconds): where a finger on the timeline lands.
    func frameSnapped(edited time: TimeInterval) -> TimeInterval {
        frameGrid.snapped(edited: time, in: edit.timeline)
    }

    /// "00:04.32 / 00:11.00"
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

    /// The line under the Trim buttons: what the timeline does right now.
    var trimHint: String {
        if removalRange != nil { return String(localized: "Drag the red edges over the part you want gone") }
        if let index = selectedJoinIndex {
            let timeline = edit.timeline
            let transition = timeline.transition(atJoin: index)
            if transition.showsBothSides, timeline.continuesFromPrevious(index) {
                return String(localized: "Nothing was cut out here, so \(transition.label) won't show")
            }
            let cut = DurationText.timecode(timeline.editedStart(ofSegmentAt: index), total: timeline.editedDuration)
            return String(localized: "Cut at \(cut) · None keeps it a hard cut")
        }
        if let index = selectedSegmentIndex, edit.timeline.segments.count > 1 {
            return String(localized: "Section \(index + 1) selected · Delete removes it")
        }
        return String(localized: "Tap to jump · drag the white line to scrub · handles trim")
    }

    /// "00:04.32 / 00:11.00, section 2 of 3, selected"
    var timelineAccessibilityValue: String {
        let timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: player.currentTime)
        var value = timeLabel
        if timeline.segments.count > 1 {
            value += ", " + String(localized: "section \(index + 1) of \(timeline.segments.count)")
        }
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

    // MARK: - Selection

    /// A tap on the timeline (the playhead already went there): selects the section under it, or
    /// lets go of it when it was already selected or the tap was beside the sections. Nothing to
    /// select while there is one section, or while "Remove part" is being placed.
    func tapTimeline(onPiece index: Int?) {
        guard removalRange == nil else { return }
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

    // MARK: - Transitions

    /// A tap on the mark of the cut before the section at `index`: selects that cut so its
    /// transition can be picked, or lets go of it when it was already selected.
    func tapJoin(_ index: Int) {
        guard removalRange == nil, index > 0, edit.timeline.segments.indices.contains(index) else { return }
        let id = edit.timeline.segments[index].id
        selectedSegmentID = nil
        selectedJoinID = selectedJoinID == id ? nil : id
    }

    /// Lets go of the selected cut.
    func closeTransitions() {
        selectedJoinID = nil
    }

    /// How the selected cut plays: a hard cut ("None"), a dissolve or a fade. An undo step; the
    /// playhead goes a moment before the cut so Play shows it.
    func setTransition(_ transition: EditTransition) {
        guard let index = selectedJoinIndex else { return }
        setTransition(transition, atJoin: index)
    }

    /// Sets the transition of the cut before the section at `index` (the Transitions tool lists
    /// every cut). An undo step; the playhead goes a moment before the cut so Play shows it.
    func setTransition(_ transition: EditTransition, atJoin index: Int) {
        guard isReady else { return }
        var timeline = edit.timeline
        guard timeline.setTransition(transition, atJoin: index) else { return }
        commit(timeline)
        if transition != .hardCut {
            player.pause()
            player.seek(to: max(0, edit.timeline.editedStart(ofSegmentAt: index) - Self.transitionLeadIn))
        }
    }

    /// The same transition on every cut, in one undo step.
    func setTransitionOnEveryCut(_ transition: EditTransition) {
        guard isReady else { return }
        var timeline = edit.timeline
        var changed = false
        for index in timeline.segments.indices.dropFirst() where timeline.setTransition(transition, atJoin: index) {
            changed = true
        }
        guard changed else { return }
        commit(timeline)
        toast.show(transition == .hardCut
            ? String(localized: "Every cut is a hard cut")
            : String(localized: "\(transition.label) on every cut"))
    }

    /// Edited seconds of every cut, by the index of the section after it.
    var cuts: [(index: Int, time: TimeInterval)] {
        edit.timeline.segments.indices.dropFirst().map { ($0, edit.timeline.editedStart(ofSegmentAt: $0)) }
    }

    // MARK: - Trim

    func beginTrim(_ handle: TrimHandle) {
        guard isReady else { return }
        endTrim()
        trimOrigin = edit.timeline
        activeHandle = handle
        removalRange = nil
        selectedSegmentID = nil
        selectedJoinID = nil
        player.pause()
    }

    /// Moves a handle to `time` (seconds of the recording) while it's dragged; the playhead and
    /// the preview follow it. Cuts don't stop it: the sections it passes leave the edit, and come
    /// back if it goes back before the finger lifts.
    func trim(_ handle: TrimHandle, toSource time: TimeInterval) {
        guard activeHandle == handle, let origin = trimOrigin else { return }
        var timeline = origin
        switch handle {
        case .start: timeline.trimStart(to: time)
        case .end: timeline.trimEnd(to: time)
        }
        if timeline != edit.timeline { edit.timeline = timeline }
        player.scrub(to: handle == .start ? 0 : timeline.editedDuration)
    }

    func endTrim() {
        guard let origin = trimOrigin else { return }
        trimOrigin = nil
        activeHandle = nil
        if origin != edit.timeline {
            var before = snapshot
            before.timeline = origin
            history.record(before)
        }
        player.endScrub()
    }

    /// VoiceOver: moves a handle by `seconds`.
    func nudgeTrim(_ handle: TrimHandle, by seconds: TimeInterval) {
        beginTrim(handle)
        let from = handle == .start ? edit.timeline.trimStart : edit.timeline.trimEnd
        trim(handle, toSource: from + seconds)
        endTrim()
    }

    // MARK: - Remove part

    /// Shows the red range around the playhead, two seconds long, to drag over what should go.
    func startRemovingPart() {
        guard isReady else { return }
        player.pause()
        let length = edit.editedDuration
        let start = max(0, min(length - Self.initialRemoval, player.currentTime - 1))
        removalRange = start...min(length, start + Self.initialRemoval)
        selectedSegmentID = nil
        selectedJoinID = nil
    }

    /// Moves an edge of the red range to `time` (edited seconds); the preview shows that frame.
    func moveRemovalEdge(_ edge: RemovalEdge, toEdited time: TimeInterval) {
        guard let range = removalRange else { return }
        let length = edit.editedDuration
        let moved: ClosedRange<TimeInterval>
        switch edge {
        case .start:
            let start = max(0, min(time, range.upperBound - Self.minimumRemoval))
            moved = start...range.upperBound
        case .end:
            let end = min(length, max(time, range.lowerBound + Self.minimumRemoval))
            moved = range.lowerBound...end
        }
        removalRange = moved
        player.scrub(to: edge == .start ? moved.lowerBound : moved.upperBound)
    }

    func cancelRemovingPart() {
        removalRange = nil
    }

    /// "Remove 00:02.10": takes the red range out (two cuts and a delete, one undo step).
    func removePart() {
        guard isReady, let range = removalRange else { return }
        var timeline = edit.timeline
        guard timeline.removeEdited(range) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        removalRange = nil
        commit(timeline)
        player.seek(to: range.lowerBound)
        toast.show(String(localized: "Removed \(DurationText.timecode(range.upperBound - range.lowerBound, total: edit.sourceDuration))"))
    }

    /// "00:02.10": how much the red range takes out.
    var removalLengthLabel: String {
        guard let range = removalRange else { return "" }
        return DurationText.timecode(range.upperBound - range.lowerBound, total: edit.editedDuration)
    }

    // MARK: - Cut and delete

    /// Cuts the section under the playhead in two and selects the second half, ready for Delete.
    func cut() {
        guard isReady else { return }
        let time = player.currentTime
        var timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: time)
        guard timeline.split(atEdited: time) else {
            toast.show(String(localized: "Move the playhead away from the edge"))
            return
        }
        removalRange = nil
        selectedJoinID = nil
        commit(timeline)
        selectedSegmentID = edit.timeline.segments[index + 1].id
        toast.show(String(localized: "Cut at \(DurationText.timecode(time, total: edit.editedDuration)) — tap a side, then Delete"))
    }

    /// Takes the selected section out of the edit.
    func removeSelection() {
        guard isReady else { return }
        guard let id = selectedSegmentID else {
            toast.show(String(localized: "Tap a section first"))
            return
        }
        var timeline = edit.timeline
        guard timeline.removeSegment(id: id) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        selectedSegmentID = nil
        commit(timeline)
        toast.show(String(localized: "Section deleted"))
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
    func commit(_ timeline: EditTimeline, suggestions: [CleanUpSuggestion]? = nil) {
        var next = snapshot
        next.timeline = timeline
        if let suggestions { next.suggestions = suggestions }
        commit(next)
    }

    /// A change undo can take back. Inside a gesture or a sheet (`beginChange`), the step was
    /// already taken when it began.
    func commit(_ next: EditSnapshot) {
        guard next != snapshot else { return }
        if changeBase == nil { history.record(snapshot) }
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

    /// Changes what undo keeps (texts, media, voice-overs, the cover, the style) as one step.
    func change(_ update: (inout EditSnapshot) -> Void) {
        var next = snapshot
        update(&next)
        commit(next)
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
        removalRange = nil
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
        if let captions = step.captions { edit.captions = captions }
    }

    // MARK: - Adjust

    func autoAdjust() {
        edit.exposure = 14
        edit.contrast = 10
        edit.warmth = 8
        toast.show(String(localized: "Auto-enhanced"))
    }

    // MARK: - Crop

    func setAspect(_ aspect: AspectRatio) {
        edit.aspect = aspect
        edit.cropOffset = 0
    }

    func resetCropPosition() {
        edit.cropOffset = 0
    }

    // MARK: - Filters

    /// A filter (an undo step, since a style sets it too).
    func setFilter(_ filter: VideoFilter) {
        change { $0.filter = filter }
    }

    /// The take's script, or nothing for a freestyle take.
    var scriptText: String {
        library.script(id: take.scriptID)?.text ?? ""
    }

    /// The language the take is heard in, for captions and Clean Up: Voice Following's.
    var speechLanguage: SpeechLanguageRequest {
        speechLanguageFor(library.script(id: take.scriptID))
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
            toast.show(String(localized: "Edits saved to \(take.label)"))
        }
        removeUnusedImports(keeping: edit.mediaFileNames)
        close(keepingDraft: false)
    }

    /// Leaves without saving on the take. Changes stay in a draft that Edit picks up again; the take
    /// is as it was.
    func cancel() {
        endTrim()
        endChange()
        if recorder.isRecording { cancelVoiceOver() }
        cancelPausePreview()
        removalRange = nil
        guard source == .ready, hasUnsavedChanges else {
            removeUnusedImports(keeping: original.mediaFileNames)
            close(keepingDraft: false)
            return
        }
        saveDraft()
        close(keepingDraft: true)
        toast.show(String(localized: "Draft kept — tap Edit to continue"))
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
    func saveDraft() {
        guard source == .ready, !isClosed else { return }
        // A pauses preview that wasn't applied isn't part of the edit.
        var kept = edit
        if let base = pausePreviewBase { Self.apply(base, to: &kept) }
        if kept != original {
            drafts.save(QuickEditDraft(takeID: take.id, edit: kept, playhead: player.currentTime, history: history, savedAt: .now))
        } else {
            drafts.discard(takeID: take.id)
        }
    }
}
