//
//  QuickEditDraftReading.swift
//  Cue Studio
//

import Foundation

/// What reading a take's draft found (`QuickEditDraftStoring.reading(for:)`).
nonisolated enum QuickEditDraftReading: Sendable {
    /// No draft: the take opens on its saved edit.
    case none
    /// The draft. `partial`: parts this version couldn't read were left out or stood in for; the file as it was is kept aside
    /// before anything is written over it.
    case draft(QuickEditDraft, partial: Bool)
    /// A draft this version can't open (damaged, or written by a newer Cue): kept aside, so writing a new one never loses it.
    case unreadable

    var draft: QuickEditDraft? {
        if case .draft(let draft, _) = self { return draft }
        return nil
    }
}
