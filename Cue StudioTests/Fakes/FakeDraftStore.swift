//
//  FakeDraftStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeDraftStore: QuickEditDraftStoring {
    var drafts: [UUID: QuickEditDraft] = [:]
    /// Like a full iPhone: no draft can be written.
    var failsToSave = false

    func draft(for takeID: UUID) -> QuickEditDraft? { drafts[takeID] }

    func save(_ draft: QuickEditDraft) throws {
        if failsToSave { throw CocoaError(.fileWriteOutOfSpace) }
        drafts[draft.takeID] = draft
    }

    func discard(takeID: UUID) { drafts[takeID] = nil }
}
