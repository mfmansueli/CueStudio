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
    /// What a write throws when it fails (a full iPhone unless set).
    var saveError: any Error = CocoaError(.fileWriteOutOfSpace)
    /// A take whose draft reads in part, or not at all, as the real store says for a damaged or newer file.
    var readings: [UUID: QuickEditDraftReading] = [:]
    /// Takes forgotten (deleted), drafts and kept copies.
    private(set) var forgotten: [UUID] = []

    func draft(for takeID: UUID) -> QuickEditDraft? { readings[takeID]?.draft ?? drafts[takeID] }

    func reading(for takeID: UUID) -> QuickEditDraftReading {
        readings[takeID] ?? drafts[takeID].map { .draft($0, partial: false) } ?? .none
    }

    func save(_ draft: QuickEditDraft) throws {
        if failsToSave { throw saveError }
        drafts[draft.takeID] = draft
        readings[draft.takeID] = nil
    }

    func discard(takeID: UUID) {
        drafts[takeID] = nil
        readings[takeID] = nil
    }

    func forget(takeID: UUID) {
        discard(takeID: takeID)
        forgotten.append(takeID)
    }

    func discardAll() { drafts = [:] }
}
