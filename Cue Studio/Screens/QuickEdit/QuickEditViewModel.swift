//
//  QuickEditViewModel.swift
//  Cue Studio
//

import Foundation

/// Quick edit of one take. The edit is a recipe (`TakeEdit`) on top of the recording, which is
/// never changed, and the player (`EditPlayback`) plays it and owns the playhead. Timeline changes
/// (trim, remove part, cut, delete, Clean Up) are undoable, together with what was decided about
/// Clean Up's suggestions; the tools set the look and sound directly. A draft is kept while
/// editing and when leaving with Cancel; Done saves the edit on the take.
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

    var tool: QuickEditTool = .trim {
        didSet {
            guard tool != oldValue else { return }
            removalRange = nil
            selectedSegmentID = nil
        }
    }
    var edit: TakeEdit {
        didSet { editDidChange() }
    }
    private(set) var source: Source = .loading
    private(set) var history = EditHistory<EditSnapshot>()
    /// The section tapped on the timeline. Separate from the playhead: scrubbing doesn't change it.
    private(set) var selectedSegmentID: UUID?
    /// The trim handle being dragged.
    private(set) var activeHandle: TrimHandle?
    /// "Remove part": the red range, in edited seconds, while it is being placed. Playing from
    /// inside it stops at its end, to watch exactly what would go.
    private(set) var removalRange: ClosedRange<TimeInterval>? {
        didSet { player.reviewedPart = removalRange }
    }
    private(set) var isWritingCaptions = false
    /// Frames per second of the recording: read from the file when it opens, the take's setting
    /// until then. The timeline puts every edit on a frame (`FrameGrid`).
    private(set) var frameRate: Double
    /// The timeline is zoomed in: the clock keeps the hundredths even on a long take.
    var showsPreciseTime = false
    /// Clean Up listening to the take (see `QuickEditViewModel+CleanUp`).
    var analysis: Analysis = .idle
    /// Clean Up's "Ignore pauses under": shorter pauses aren't listed and stay as natural ones.
    var pauseThreshold: TimeInterval = QuickEditViewModel.defaultPauseThreshold

    let take: Take
    let player: EditPlayback
    let editing: TakeEditing
    let library: ScriptLibraryService
    let toast: ToastService
    private let takes: TakeLibraryService
    private let drafts: QuickEditDraftStoring
    /// The take's edit when Quick edit opened.
    private var original: TakeEdit
    /// The timeline when a handle drag started, so a whole drag is one undo step.
    @ObservationIgnored private var trimOrigin: EditTimeline?
    @ObservationIgnored private var draftTask: Task<Void, Never>?
    @ObservationIgnored private(set) var isClosed = false

    init(
        take: Take, takes: TakeLibraryService, library: ScriptLibraryService, editing: TakeEditing,
        drafts: QuickEditDraftStoring, toast: ToastService, player: EditPlayback? = nil
    ) {
        self.take = take
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

    var canUndo: Bool { history.canUndo && activeHandle == nil }
    var canRedo: Bool { history.canRedo && activeHandle == nil }
    var canDeleteSelection: Bool { selectedSegmentID != nil && edit.timeline.segments.count > 1 }
    var hasUnsavedChanges: Bool { edit != original }

    var selectedSegmentIndex: Int? {
        selectedSegmentID.flatMap { edit.timeline.index(ofSegment: $0) }
    }

    /// The line under the Trim buttons: what the timeline does right now.
    var trimHint: String {
        if removalRange != nil { return String(localized: "Drag the red edges over the part you want gone") }
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
            return
        }
        let id = edit.timeline.segments[index].id
        selectedSegmentID = selectedSegmentID == id ? nil : id
    }

    func selectPieceAtPlayhead() {
        tapTimeline(onPiece: edit.timeline.segmentIndex(atEdited: player.currentTime))
    }

    // MARK: - Trim

    func beginTrim(_ handle: TrimHandle) {
        guard isReady else { return }
        endTrim()
        trimOrigin = edit.timeline
        activeHandle = handle
        removalRange = nil
        selectedSegmentID = nil
        player.pause()
    }

    /// Moves a handle to `time` (seconds of the recording) while it's dragged; the playhead and
    /// the preview follow it.
    func trim(_ handle: TrimHandle, toSource time: TimeInterval) {
        guard activeHandle == handle else { return }
        var timeline = edit.timeline
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
        if origin != edit.timeline { history.record(EditSnapshot(timeline: origin, suggestions: edit.suggestions)) }
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
        guard canUndo, let previous = history.undo(from: snapshot) else { return }
        restore(previous)
    }

    func redo() {
        guard canRedo, let next = history.redo(from: snapshot) else { return }
        restore(next)
    }

    /// The timeline and the suggestions' decisions, as undo keeps them.
    var snapshot: EditSnapshot {
        EditSnapshot(timeline: edit.timeline, suggestions: edit.suggestions)
    }

    /// A change undo can take back: a new timeline, and new decisions about suggestions.
    func commit(_ timeline: EditTimeline, suggestions: [CleanUpSuggestion]? = nil) {
        let next = EditSnapshot(timeline: timeline, suggestions: suggestions ?? edit.suggestions)
        guard next != snapshot else { return }
        history.record(snapshot)
        var changed = edit
        changed.timeline = next.timeline
        changed.suggestions = next.suggestions
        edit = changed
    }

    /// Goes back (or forward) to a step. Suggestions found since keep their place and take the
    /// step's decision, or wait for review when the step didn't know them yet.
    private func restore(_ step: EditSnapshot) {
        let decisions = Dictionary(step.suggestions.map { ($0.id, $0.status) }, uniquingKeysWith: { first, _ in first })
        var changed = edit
        changed.timeline = step.timeline
        changed.suggestions = edit.suggestions.map { suggestion in
            var restored = suggestion
            restored.status = decisions[suggestion.id] ?? .pending
            return restored
        }
        removalRange = nil
        edit = changed
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

    // MARK: - Captions

    /// Captions come from the script (or, freestyle, from what the model hears), timed to the voice.
    func setShowsCaptions(_ shows: Bool) async {
        edit.showsCaptions = shows
        guard shows, edit.captions.isEmpty else { return }
        isWritingCaptions = true
        defer { isWritingCaptions = false }
        edit.captions = await editing.captions(forVideoAt: videoURL, script: scriptText, duration: edit.sourceDuration)
        if edit.captions.isEmpty {
            edit.showsCaptions = false
            toast.show(String(localized: "No script to caption this take"))
        }
    }

    func setCaptionStyle(_ style: CaptionStyle) async {
        edit.captionStyle = style
        if !edit.showsCaptions { await setShowsCaptions(true) }
    }

    /// The take's script, or nothing for a freestyle take.
    var scriptText: String {
        library.script(id: take.scriptID)?.text ?? ""
    }

    // MARK: - Leaving

    /// Saves the edit on the take (its new length, marked Edited) when anything changed.
    func done() {
        endTrim()
        if source == .ready, hasUnsavedChanges {
            takes.applyEdit(edit, to: take.id)
            toast.show(String(localized: "Edits saved to \(take.label)"))
        }
        close(keepingDraft: false)
    }

    /// Leaves without saving on the take. Changes stay in a draft that Edit picks up again; the take
    /// is as it was.
    func cancel() {
        endTrim()
        removalRange = nil
        guard source == .ready, hasUnsavedChanges else {
            close(keepingDraft: false)
            return
        }
        saveDraft()
        close(keepingDraft: true)
        toast.show(String(localized: "Draft kept — tap Edit to continue"))
    }

    /// Leaving the app or the screen without Done or Cancel: the draft keeps everything.
    func pauseAndKeepDraft() {
        player.pause()
        saveDraft()
    }

    private func close(keepingDraft: Bool) {
        isClosed = true
        draftTask?.cancel()
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
        if hasUnsavedChanges {
            drafts.save(QuickEditDraft(takeID: take.id, edit: edit, playhead: player.currentTime, history: history, savedAt: .now))
        } else {
            drafts.discard(takeID: take.id)
        }
    }
}
