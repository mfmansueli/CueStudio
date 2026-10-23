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
    /// Keeps the draft without making the caller wait (the autosave while editing): written off the main thread, after every
    /// write or discard asked for before it, so an older draft never lands over a newer one or over a discard. A draft that
    /// can't be written is logged; the next autosave, or the draft kept on leaving (`save`), tries again.
    func saveSoon(_ draft: QuickEditDraft)
    func discard(takeID: UUID)
    /// "Delete my Cue data": every draft, the ones of takes already gone too.
    func discardAll()
}

extension QuickEditDraftStoring {
    func hasDraft(for takeID: UUID) -> Bool { draft(for: takeID) != nil }

    func saveSoon(_ draft: QuickEditDraft) { try? save(draft) }
}
