//
//  InMemoryQuickEditDraftStore.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Keeps Quick edit drafts in memory. For previews and UI tests.
final class InMemoryQuickEditDraftStore: QuickEditDraftStoring {
    private var drafts: [UUID: QuickEditDraft] = [:]

    func draft(for takeID: UUID) -> QuickEditDraft? { drafts[takeID] }

    func save(_ draft: QuickEditDraft) { drafts[draft.takeID] = draft }

    func discard(takeID: UUID) { drafts[takeID] = nil }
}
#endif
