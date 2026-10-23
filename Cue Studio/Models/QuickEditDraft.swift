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
    /// Undo steps (`EditSnapshot`). Steps that can't be read start over; the edit is kept.
    var history: EditHistory<EditSnapshot>
    var savedAt: Date

    init(takeID: UUID, edit: TakeEdit, playhead: TimeInterval, history: EditHistory<EditSnapshot>, savedAt: Date) {
        self.takeID = takeID
        self.edit = edit
        self.playhead = playhead
        self.history = history
        self.savedAt = savedAt
    }

    private enum CodingKeys: String, CodingKey {
        case takeID, edit, playhead, history, savedAt
    }

    /// The edit is what matters: undo steps that can't be read (a newer version's, or a damaged one) start over, and the
    /// draft still opens where it was.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        takeID = try container.decode(UUID.self, forKey: .takeID)
        edit = try container.decode(TakeEdit.self, forKey: .edit)
        playhead = (try? container.decodeIfPresent(TimeInterval.self, forKey: .playhead)) ?? 0
        history = container.decodeLenient(EditHistory<EditSnapshot>.self, forKey: .history, report: decoder.decodingReport) ?? EditHistory()
        savedAt = (try? container.decodeIfPresent(Date.self, forKey: .savedAt)) ?? .now
    }
}
