//
//  QuickEditViewModel.swift
//  Cue Studio
//

import Foundation

/// Quick edit of one take. The edit is a recipe (`TakeEdit`) on top of the recording, which is
/// never changed, and the player (`EditPlayback`) plays it and owns the playhead. Timeline changes
/// (trim, cut, remove, Clean Up) are undoable; the tools set the look and sound directly. A draft
/// is kept while editing; Done saves the edit on the take, Cancel throws it away.
@MainActor
@Observable
final class QuickEditViewModel {
    /// Whether the recording could be opened.
    enum Source: Equatable {
        case loading, ready, unavailable
    }

    var tool: QuickEditTool = .trim
    var edit: TakeEdit {
        didSet { editDidChange() }
    }
    private(set) var source: Source = .loading
    private(set) var history = EditHistory<EditTimeline>()
    /// The piece tapped on the timeline. Separate from the playhead: scrubbing doesn't change it.
    private(set) var selectedSegmentID: UUID?
    /// The trim handle being dragged.
    private(set) var activeHandle: TrimHandle?
    private(set) var isFindingSilences = false
    private(set) var isWritingCaptions = false
    /// Cancel with changes asks first.
    var confirmsDiscard = false
    /// Clean Up's review of what it found is open.
    var showsCleanUp = false

    let take: Take
    let player: EditPlayback
    private let takes: TakeLibraryService
    private let library: ScriptLibraryService
    private let editing: TakeEditing
    private let drafts: QuickEditDraftStoring
    private let toast: ToastService
    /// The take's edit when Quick edit opened: what Cancel goes back to.
    private var original: TakeEdit
    /// The timeline when a handle drag started, so a whole drag is one undo step.
    @ObservationIgnored private var trimOrigin: EditTimeline?
    @ObservationIgnored private var draftTask: Task<Void, Never>?
    @ObservationIgnored private var isClosed = false

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
            toast.show(String(localized: "Picked up where you left off"))
        }
        edit = start
        source = .ready
        player.show(edit)
        player.seek(to: playhead)
    }

    private func editDidChange() {
        guard source == .ready else { return }
        if let id = selectedSegmentID, edit.timeline.segment(id: id) == nil { selectedSegmentID = nil }
        player.show(edit)
        scheduleDraftSave()
    }

    // MARK: - Reading

    var videoURL: URL { takes.videoURL(for: take) }

    /// The recording is open and the preview can play.
    var isReady: Bool { source == .ready && player.state != .failed }

    /// "1:04 → 0:58"
    var durationChange: String {
        DurationText.clock(edit.sourceDuration) + " → " + DurationText.clock(edit.editedDuration)
    }

    /// "00:04.32 / 00:11.00": the playhead and the edit's length. It reads the player's clock, so
    /// only the small views that show it redraw while the video plays.
    var timeLabel: String {
        let total = edit.sourceDuration
        return DurationText.timecode(player.currentTime, total: total) + " / " + DurationText.timecode(edit.editedDuration, total: total)
    }

    var canUndo: Bool { history.canUndo && activeHandle == nil }
    var canRedo: Bool { history.canRedo && activeHandle == nil }
    var canRemoveSelection: Bool { selectedSegmentID != nil && edit.timeline.segments.count > 1 }
    var hasUnsavedChanges: Bool { edit != original }

    var selectedSegmentIndex: Int? {
        selectedSegmentID.flatMap { edit.timeline.index(ofSegment: $0) }
    }

    /// "00:04.32 / 00:11.00, piece 2 of 3, selected"
    var timelineAccessibilityValue: String {
        let timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: player.currentTime)
        var value = timeLabel
        if timeline.segments.count > 1 {
            value += ", " + String(localized: "piece \(index + 1) of \(timeline.segments.count)")
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

    /// A tap on the timeline (the playhead already went there): selects the piece under it, or
    /// lets go of the selection beside the pieces.
    func tapTimeline(onPiece index: Int?) {
        guard let index, edit.timeline.segments.indices.contains(index) else {
            selectedSegmentID = nil
            return
        }
        selectedSegmentID = edit.timeline.segments[index].id
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
        if origin != edit.timeline { history.record(origin) }
        player.endScrub()
    }

    /// VoiceOver: moves a handle by `seconds`.
    func nudgeTrim(_ handle: TrimHandle, by seconds: TimeInterval) {
        beginTrim(handle)
        let from = handle == .start ? edit.timeline.trimStart : edit.timeline.trimEnd
        trim(handle, toSource: from + seconds)
        endTrim()
    }

    // MARK: - Cut and remove

    /// Cuts the piece under the playhead in two.
    func cut() {
        guard isReady else { return }
        let time = player.currentTime
        var timeline = edit.timeline
        guard timeline.split(atEdited: time) else {
            toast.show(String(localized: "Move the playhead away from the edges to cut"))
            return
        }
        selectedSegmentID = nil
        commit(timeline)
        toast.show(String(localized: "Cut at \(DurationText.timecode(time, total: edit.sourceDuration))"))
    }

    /// Takes the selected piece out of the edit.
    func removeSelection() {
        guard isReady else { return }
        guard let id = selectedSegmentID else {
            toast.show(String(localized: "Tap a piece to select it"))
            return
        }
        var timeline = edit.timeline
        guard timeline.removeSegment(id: id) else {
            toast.show(String(localized: "Keep at least one piece"))
            return
        }
        selectedSegmentID = nil
        commit(timeline)
        toast.show(String(localized: "Piece removed"))
    }

    // MARK: - Undo

    func undo() {
        guard canUndo, let previous = history.undo(from: edit.timeline) else { return }
        edit.timeline = previous
    }

    func redo() {
        guard canRedo, let next = history.redo(from: edit.timeline) else { return }
        edit.timeline = next
    }

    /// A timeline change undo can take back.
    private func commit(_ timeline: EditTimeline) {
        guard timeline != edit.timeline else { return }
        history.record(edit.timeline)
        edit.timeline = timeline
    }

    // MARK: - Clean Up

    /// How much of the take plays before a finding when it's previewed, so it's heard in context.
    static let suggestionLeadIn: TimeInterval = 1

    /// What Clean Up found between the handles, in the order it's heard, kept ones included.
    /// Findings are suggestions: nothing leaves the edit until the creator removes it.
    var cleanUpSuggestions: [CleanUpSuggestion] {
        let timeline = edit.timeline
        return edit.suggestions
            .filter { $0.span.start >= timeline.trimStart && $0.span.end <= timeline.trimEnd }
            .sorted { $0.span.start < $1.span.start }
    }

    /// Whether a finding no longer plays.
    func isRemoved(_ suggestion: CleanUpSuggestion) -> Bool {
        edit.timeline.isRemoved(suggestion.span)
    }

    /// Pauses found in the take, between the handles, that the creator hasn't chosen to keep.
    private var pauses: [CleanUpSuggestion] {
        cleanUpSuggestions.filter { $0.kind == .pause && !$0.isKept }
    }

    private var removedPauses: [TimeSpan] {
        pauses.map(\.span).filter(edit.timeline.isRemoved)
    }

    var silencesAreRemoved: Bool { !removedPauses.isEmpty }

    /// Pauses "Remove all" would take out: not kept and still playing.
    var pausesLeftToRemove: Int {
        pauses.filter { !edit.timeline.isRemoved($0.span) }.count
    }

    /// "Remove silences · 4" or "Silences removed · −3s".
    var silenceLabel: String {
        let removed = removedPauses
        if !removed.isEmpty {
            let cut = Int(SilenceDetector.totalDuration(of: removed).rounded())
            return String(localized: "Silences removed · −\(cut)s")
        }
        let found = pauses.count
        return found == 0 ? String(localized: "Remove silences") : String(localized: "Remove silences · \(found)")
    }

    /// Finds the pauses the first time, then opens the review: each one can be kept or removed,
    /// or all removed at once.
    func reviewCleanUp() async {
        guard isReady, !isFindingSilences, await findPausesIfNeeded() else { return }
        showsCleanUp = true
    }

    /// "Remove all": the pauses not kept go, in one step undo takes back.
    func removeAllPauses() {
        var timeline = edit.timeline
        guard timeline.remove(pauses.map(\.span)) else {
            toast.show(String(localized: "No long pauses in this take"))
            return
        }
        commit(timeline)
    }

    /// "Put all back": the removed pauses play again, in one step.
    func restoreRemovedPauses() {
        var timeline = edit.timeline
        timeline.restore(removedPauses)
        commit(timeline)
    }

    /// Takes one finding out of the edit, like any cut (undo brings it back).
    func removeSuggestion(_ id: UUID) {
        guard isReady, let index = edit.suggestions.firstIndex(where: { $0.id == id }) else { return }
        let span = edit.suggestions[index].span
        var timeline = edit.timeline
        guard timeline.remove([span]) else {
            if !edit.timeline.isRemoved(span) { toast.show(String(localized: "Keep at least one piece")) }
            return
        }
        if edit.suggestions[index].isKept { edit.suggestions[index].isKept = false }
        commit(timeline)
    }

    /// Keeps a finding: it plays again if it was removed, and "Remove all" leaves it alone.
    func keepSuggestion(_ id: UUID) {
        guard isReady, let index = edit.suggestions.firstIndex(where: { $0.id == id }) else { return }
        let span = edit.suggestions[index].span
        if !edit.suggestions[index].isKept { edit.suggestions[index].isKept = true }
        var timeline = edit.timeline
        timeline.restore([span])
        commit(timeline)
    }

    /// Plays from a moment before a finding (or from where the edit picks up, when it's removed),
    /// so the creator hears whether it helps.
    func playSuggestion(_ id: UUID) {
        guard isReady, let suggestion = edit.suggestions.first(where: { $0.id == id }) else { return }
        let timeline = edit.timeline
        let from = max(timeline.trimStart, suggestion.span.start - Self.suggestionLeadIn)
        player.seek(to: timeline.editedTime(following: from))
        player.play()
    }

    /// Looks for pauses once. False, with a message, when there are none between the handles.
    private func findPausesIfNeeded() async -> Bool {
        if !edit.suggestions.contains(where: { $0.kind == .pause }) {
            isFindingSilences = true
            let found = try? await editing.silences(inVideoAt: videoURL)
            isFindingSilences = false
            guard !isClosed else { return false }
            guard let found else {
                toast.show(String(localized: "Couldn't listen to this take"))
                return false
            }
            edit.suggestions += found.map { CleanUpSuggestion(kind: .pause, span: $0, confidence: 1) }
        }
        guard cleanUpSuggestions.contains(where: { $0.kind == .pause }) else {
            toast.show(String(localized: "No long pauses in this take"))
            return false
        }
        return true
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
        let script = library.script(id: take.scriptID)?.text ?? ""
        edit.captions = await editing.captions(forVideoAt: videoURL, script: script, duration: edit.sourceDuration)
        if edit.captions.isEmpty {
            edit.showsCaptions = false
            toast.show(String(localized: "No script to caption this take"))
        }
    }

    func setCaptionStyle(_ style: CaptionStyle) async {
        edit.captionStyle = style
        if !edit.showsCaptions { await setShowsCaptions(true) }
    }

    // MARK: - Leaving

    /// Saves the edit on the take (its new length, marked Edited) when anything changed.
    func done() {
        endTrim()
        if source == .ready, hasUnsavedChanges {
            takes.applyEdit(edit, to: take.id)
            toast.show(String(localized: "Edits saved to \(take.label)"))
        }
        close()
    }

    /// Cancel: true when the screen can close now. With changes it asks first
    /// (`confirmsDiscard`).
    func cancel() -> Bool {
        endTrim()
        guard source == .ready, hasUnsavedChanges else {
            close()
            return true
        }
        confirmsDiscard = true
        return false
    }

    /// Throws the changes away.
    func discard() {
        close()
    }

    /// Leaving the app or the screen without Done or Cancel: the draft keeps everything.
    func pauseAndKeepDraft() {
        player.pause()
        saveDraft()
    }

    private func close() {
        isClosed = true
        draftTask?.cancel()
        drafts.discard(takeID: take.id)
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
