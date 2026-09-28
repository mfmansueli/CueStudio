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
    var history: EditHistory<EditTimeline>
    var savedAt: Date
}
