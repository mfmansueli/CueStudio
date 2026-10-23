//
//  EditDocument.swift
//  Cue Studio
//

import Foundation

/// The take's edit while Quick edit is open, with its undo steps: the one place the edit changes. What the creator decides
/// is an undo step (`changeEdit`, `change`, `commit`; a gesture or a sheet is one step, `beginChange` / `endChange`), Undo
/// and Redo move between steps (`undo`, `redo`), and what listening found is laid on without one (`updateFindings`). The
/// editor hears every change (`onChange`) and does the rest: the preview, the draft, the cover, letting go of what's gone.
@MainActor
@Observable
final class EditDocument {
    /// The recipe being edited.
    private(set) var edit: TakeEdit {
        didSet { onChange(oldValue) }
    }
    private(set) var history = EditHistory<EditSnapshot>()
    /// The take's edit when Quick edit opened: Done saves only when the edit differs, and files it names stay.
    private(set) var original: TakeEdit
    /// The undo step a gesture or a sheet started from (`beginChange`).
    @ObservationIgnored private(set) var changeBase: EditSnapshot?
    /// Told after every change of the edit, with the edit before it.
    @ObservationIgnored var onChange: (_ previous: TakeEdit) -> Void = { _ in }

    init(_ edit: TakeEdit) {
        original = edit
        self.edit = edit
    }

    var hasUnsavedChanges: Bool { edit != original }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    /// What undo keeps of the edit: the timeline, the suggestions' decisions, what was added on top and the look a style sets.
    var snapshot: EditSnapshot { EditSnapshot(edit) }

    // MARK: - Opening

    /// The recording opened: the take's edit fits the file's own length, and a draft left behind that differs from it is
    /// picked up with its undo steps. True when the draft was.
    @discardableResult
    func open(sourceDuration duration: TimeInterval, draft: QuickEditDraft?) -> Bool {
        original.timeline = original.timeline.fitted(toSourceDuration: duration)
        guard let draft, draft.edit != original else {
            edit = original
            return false
        }
        var start = draft.edit
        start.captions = start.captions.map(CaptionRevision.withoutContinuation)
        start.timeline = start.timeline.fitted(toSourceDuration: duration)
        history = draft.history
        edit = start
        return true
    }

    // MARK: - Changing

    /// A change undo can take back: a new timeline, and new decisions about suggestions.
    func commit(_ timeline: EditTimeline, suggestions: [CleanUpSuggestion]? = nil, key: String? = nil) {
        var next = snapshot
        next.timeline = timeline
        if let suggestions { next.suggestions = suggestions }
        commit(next, key: key)
    }

    /// A change undo can take back. Inside a gesture or a sheet (`beginChange`), the step was already taken when it began.
    /// Changes with the same `key` in a quick row (a slider, typing) are one step (`EditHistory.coalescingInterval`).
    func commit(_ next: EditSnapshot, key: String? = nil) {
        var next = next
        // Sound effects and extracted sounds follow the moment they were put on when the cuts change (and nothing moved them in
        // this step). Inside a gesture, from where the gesture began, so dragging a handle out and back leaves them where they were.
        let current = snapshot
        let origin = changeBase ?? current
        if next.timeline != current.timeline, next.music == current.music, let music = origin.music, music.contains(where: \.followsTheVideo) {
            let followed = MusicClip.following(music, from: origin.timeline, to: next.timeline)
            next.music = current.music?.map { clip in
                clip.followsTheVideo ? (followed.first { $0.id == clip.id } ?? clip) : clip
            }
        }
        guard next != current else { return }
        if changeBase == nil { history.record(current, key: key, at: .now) }
        var changed = edit
        changed.apply(next)
        edit = changed
    }

    /// Changes what undo keeps (texts, media, voice-overs, the cover, the style) as one step; with a `key`, quick changes of
    /// the same kind join one step.
    func change(key: String? = nil, _ update: (inout EditSnapshot) -> Void) {
        var next = snapshot
        update(&next)
        commit(next, key: key)
    }

    /// Changes anything the creator decides on the edit (light, frame, sound, captions shown, what is locked…) as one undo
    /// step; with a `key`, quick changes of the same kind join one step. What listening found isn't the creator's to change
    /// here (`updateFindings`).
    func changeEdit(key: String? = nil, _ update: (inout TakeEdit) -> Void) {
        var changed = edit
        update(&changed)
        assert(Self.findings(of: changed) == Self.findings(of: edit), "What listening found changes with updateFindings")
        commit(EditSnapshot(changed), key: key)
    }

    /// Puts what listening found on the edit (transcripts, Clean Up's suggestions, which recordings were heard): never an
    /// undo step, and Undo leaves it (`restore` keeps new suggestions waiting for review). Everything the creator decides
    /// stays as it is.
    func updateFindings(_ update: (inout TakeEdit) -> Void) {
        var changed = edit
        update(&changed)
        var decided = EditSnapshot(changed)
        decided.suggestions = snapshot.suggestions
        assert(decided == snapshot, "A decision of the creator changes with changeEdit, as an undo step")
        edit = changed
    }

    /// What listening found: the part of the edit no undo step keeps.
    private static func findings(of edit: TakeEdit) -> [AnyHashable] {
        [edit.cleanUpAnalyzed, edit.cleanUpAnalyzedSources, edit.captionTranscript, edit.sourceTranscripts]
    }

    /// A gesture or a sheet starts changing something, maybe many times: all of it is one undo step, taken when it ends
    /// (`endChange`).
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

    // MARK: - Undo

    /// Goes back a step (ending a gesture or sheet first); false when there was none.
    @discardableResult
    func undo() -> Bool {
        endChange()
        guard let previous = history.undo(from: snapshot) else { return false }
        restore(previous)
        return true
    }

    /// Goes forward to the step undone last; false when there was none.
    @discardableResult
    func redo() -> Bool {
        endChange()
        guard let next = history.redo(from: snapshot) else { return false }
        restore(next)
        return true
    }

    /// Goes back (or forward) to a step. Suggestions found since keep their place and take the step's decision, or wait for
    /// review when the step didn't know them yet.
    private func restore(_ step: EditSnapshot) {
        let decisions = Dictionary(step.suggestions.map { ($0.id, $0.status) }, uniquingKeysWith: { first, _ in first })
        var changed = edit
        changed.apply(step)
        changed.suggestions = edit.suggestions.map { suggestion in
            var restored = suggestion
            restored.status = decisions[suggestion.id] ?? .pending
            return restored
        }
        edit = changed
    }
}
