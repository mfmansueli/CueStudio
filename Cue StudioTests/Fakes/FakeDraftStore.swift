//
//  FakeDraftStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeDraftStore: QuickEditDraftStoring {
    var drafts: [UUID: QuickEditDraft] = [:]

    func draft(for takeID: UUID) -> QuickEditDraft? { drafts[takeID] }

    func save(_ draft: QuickEditDraft) { drafts[draft.takeID] = draft }

    func discard(takeID: UUID) { drafts[takeID] = nil }
}
