//
//  EditorDraftKeeperTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A store whose autosaves finish when the test says, in any order: like writes that land late.
@MainActor
private final class DeferredDraftStore: QuickEditDraftStoring {
    var pending: [(QuickEditDraft, @MainActor @Sendable (QuickEditDraftSaveFailure?) -> Void)] = []
    func draft(for takeID: UUID) -> QuickEditDraft? { nil }
    func save(_ draft: QuickEditDraft) throws {}
    func saveSoon(_ draft: QuickEditDraft, then: @escaping @MainActor @Sendable (QuickEditDraftSaveFailure?) -> Void) {
        pending.append((draft, then))
    }
    func discard(takeID: UUID) {}
    func discardAll() {}
}

@MainActor
private final class Told {
    var firsts: [Bool] = []
}

@MainActor
@Suite("EditorDraftKeeper")
struct EditorDraftKeeperTests {
    private func draft(_ id: UUID) -> QuickEditDraft {
        QuickEditDraft(takeID: id, edit: TakeEdit(sourceDuration: 10, aspect: .portrait), playhead: 0, history: EditHistory(), savedAt: TestData.now)
    }

    /// The chip says Saved only for the newest change: an older write that finishes after a newer change never marks it kept.
    @Test func anOlderWriteFinishingLateNeverSaysANewerChangeIsSaved() {
        let store = DeferredDraftStore(), id = UUID()
        let keeper = EditorDraftKeeper(store: store, takeID: id)
        keeper.changed(hasChanges: true)
        keeper.saveSoon(draft(id)) { _, _ in }
        keeper.changed(hasChanges: true)
        #expect(keeper.state == .saving)
        store.pending[0].1(nil)
        #expect(keeper.state == .saving)
        keeper.saveSoon(draft(id)) { _, _ in }
        store.pending[1].1(nil)
        #expect(keeper.state == .saved)
    }

    /// A failed write is said once per run of failures, and the next one that works clears it.
    @Test func failuresAreSaidOnceUntilAWriteWorks() {
        let store = DeferredDraftStore(), id = UUID()
        let keeper = EditorDraftKeeper(store: store, takeID: id)
        let told = Told()
        for _ in 0..<3 {
            keeper.changed(hasChanges: true)
            keeper.saveSoon(draft(id)) { _, first in told.firsts.append(first) }
            store.pending.removeLast().1(.noSpace)
        }
        #expect(told.firsts == [true, false, false])
        #expect(keeper.state == .failed(.noSpace))
        keeper.changed(hasChanges: true)
        keeper.saveSoon(draft(id)) { _, _ in }
        store.pending.removeLast().1(nil)
        #expect(keeper.state == .saved)
        #expect(!keeper.isFailing)
    }

    @Test func backToNoChangesIsClean() {
        let keeper = EditorDraftKeeper(store: DeferredDraftStore(), takeID: UUID())
        keeper.opened(onDraft: true)
        #expect(keeper.state == .saved)
        keeper.changed(hasChanges: false)
        #expect(keeper.state == .clean)
    }
}
