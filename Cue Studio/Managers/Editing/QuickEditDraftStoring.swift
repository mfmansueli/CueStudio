//
//  QuickEditDraftStoring.swift
//  Cue Studio
//

import Foundation

/// Where Quick edit keeps an edit in progress, one per take.
protocol QuickEditDraftStoring: AnyObject {
    func draft(for takeID: UUID) -> QuickEditDraft?
    /// Whether an edit is open on the take: what puts its video "In edit" in Takes. Cheap, so lists
    /// can ask for every take.
    func hasDraft(for takeID: UUID) -> Bool
    /// Throws when the draft couldn't be written (the iPhone full): the edit is then only in memory.
    func save(_ draft: QuickEditDraft) throws
    func discard(takeID: UUID)
}

extension QuickEditDraftStoring {
    func hasDraft(for takeID: UUID) -> Bool { draft(for: takeID) != nil }
}
