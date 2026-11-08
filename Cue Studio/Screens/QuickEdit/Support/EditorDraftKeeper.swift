//
//  EditorDraftKeeper.swift
//  Cue Studio
//

import Foundation

/// Whether the edit on screen is the one on disk, for the top bar's "● IN EDIT · AUTOSAVED": each change bumps a revision, and only
/// the write of the newest revision says Saved, so an older write that finishes late never marks newer changes as kept.
@Observable
final class EditorDraftKeeper {
    enum State: Equatable {
        /// Nothing changed: no draft is needed.
        case clean
        /// A change isn't on disk yet (the autosave waits 600 ms, then writes).
        case saving
        /// The edit on screen is the draft on disk.
        case saved
        /// The last write of the edit on screen failed; Cue tries again.
        case failed(QuickEditDraftSaveFailure)
    }

    private(set) var state: State = .clean
    @ObservationIgnored private var revision = 0
    /// Writes have failed since the last one that worked.
    @ObservationIgnored private(set) var isFailing = false
    @ObservationIgnored private let store: QuickEditDraftStoring
    @ObservationIgnored private let takeID: UUID

    init(store: QuickEditDraftStoring, takeID: UUID) {
        self.store = store
        self.takeID = takeID
    }

    /// The editor opened: on a draft restored from disk (saved), or on the take's edit.
    func opened(onDraft: Bool) {
        state = onDraft ? .saved : .clean
    }

    /// The edit changed: what is on disk is now older, until the next write.
    func changed(hasChanges: Bool) {
        revision += 1
        state = hasChanges ? .saving : .clean
    }

    /// The autosave: written off the main thread. `failed` hears a write that failed while it was still the newest, and whether it
    /// is the first failure after one that worked (so the creator is told once, not every few seconds).
    func saveSoon(_ draft: QuickEditDraft, failed: @escaping @MainActor @Sendable (QuickEditDraftSaveFailure, _ first: Bool) -> Void) {
        let written = revision
        store.saveSoon(draft) { [weak self] failure in
            guard let self, written == self.revision else { return }
            self.settle(failure, failed: failed)
        }
    }

    /// Written now (leaving, or Cue going to the background). Nil when it made it, else the error (for the failure report).
    func saveNow(_ draft: QuickEditDraft) -> (any Error)? {
        do {
            try store.save(draft)
            state = .saved
            isFailing = false
            return nil
        } catch {
            state = .failed(QuickEditDraftSaveFailure(error))
            isFailing = true
            return error
        }
    }

    /// Nothing is changed any more: no draft.
    func discard() {
        store.discard(takeID: takeID)
        state = .clean
        isFailing = false
    }

    private func settle(_ failure: QuickEditDraftSaveFailure?, failed: @MainActor (QuickEditDraftSaveFailure, _ first: Bool) -> Void) {
        guard let failure else {
            state = .saved
            isFailing = false
            return
        }
        let first = !isFailing
        isFailing = true
        state = .failed(failure)
        failed(failure, first)
    }
}
