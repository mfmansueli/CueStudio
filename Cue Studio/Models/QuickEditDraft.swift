//
//  QuickEditDraft.swift
//  Cue Studio
//

import Foundation

/// An edit in progress, kept while Quick edit is open so leaving the app (or the app being
/// closed) never loses it. Removed when the edit is saved with Done or discarded with Cancel.
nonisolated struct QuickEditDraft: Codable, Hashable, Sendable {
    /// The take, whose recording is the source of the edit.
    var takeID: UUID
    var edit: TakeEdit
    /// Edited seconds.
    var playhead: TimeInterval
    /// Undo steps: the timeline and the suggestions' statuses. Drafts saved before suggestions were
    /// part of undo can't be read, which only means the edit starts from the take's saved one.
    var history: EditHistory<EditSnapshot>
    var savedAt: Date
}
