//
//  QuickEditDraftStoring.swift
//  Cue Studio
//

import Foundation

/// Where Quick edit keeps an edit in progress, one per take.
protocol QuickEditDraftStoring: AnyObject {
    func draft(for takeID: UUID) -> QuickEditDraft?
    /// The draft and how it read (`QuickEditDraftReading`): what the editor opens on, and says when a draft came back in part or not at
    /// all.
    func reading(for takeID: UUID) -> QuickEditDraftReading
    /// Whether an edit is open on the take: what puts its video "In edit" in Takes. Cheap, so lists
    /// can ask for every take.
    func hasDraft(for takeID: UUID) -> Bool
    /// Throws when the draft couldn't be written (the iPhone full): the edit is then only in memory.
    func save(_ draft: QuickEditDraft) throws
    /// Keeps the draft without making the caller wait (the autosave while editing): written off the main thread, after every
    /// write or discard asked for before it, so an older draft never lands over a newer one or over a discard. `then` hears, on the
    /// main actor, whether this write made it (nil) or why not.
    func saveSoon(_ draft: QuickEditDraft, then: @escaping @MainActor @Sendable (QuickEditDraftSaveFailure?) -> Void)
    func discard(takeID: UUID)
    /// The take is gone: its draft and the copies kept of drafts that couldn't be read.
    func forget(takeID: UUID)
    /// "Delete my Cue data": every draft, the ones of takes already gone too.
    func discardAll()
}

extension QuickEditDraftStoring {
    func hasDraft(for takeID: UUID) -> Bool { draft(for: takeID) != nil }

    func reading(for takeID: UUID) -> QuickEditDraftReading {
        draft(for: takeID).map { .draft($0, partial: false) } ?? .none
    }

    func forget(takeID: UUID) { discard(takeID: takeID) }

    /// The take of `takes` whose edit was left open last, if one has an open edit: what "In edit", "Continue" and the reminder to finish
    /// open, so the creator finds the edit where they left it (reads the drafts: for a tap, not for every frame).
    func takeInEdit(among takes: [Take]) -> Take? {
        takes.compactMap { take in hasDraft(for: take.id) ? (take, draft(for: take.id)?.savedAt ?? .distantPast) : nil }
            .max { $0.1 < $1.1 }?.0
    }

    /// The edit left open on `take`, when it would change the video: what Save and Share ask about first. An editor opened and left as it
    /// was ("Not yet" keeps a draft even then) or a draft equal to the finished edit is not one.
    func unfinishedEdit(of take: Take) -> QuickEditDraft? {
        guard let draft = draft(for: take.id) else { return nil }
        var start = QuickEditViewModel.startingEdit(for: take)
        start.timeline = start.timeline.fitted(toSourceDuration: draft.edit.timeline.sourceDuration)
        var left = draft.edit
        left.captions = left.captions.map(CaptionRevision.withoutContinuation)
        // Captions an export heard while the draft waited aren't the creator's change: the editor takes them in (`EditDocument.open`).
        if let edit = take.edit { left = left.withCaptionsHeardMeanwhile(from: edit) }
        // A new edit names its pieces anew each time it is made: the same untouched recording, named otherwise, is no change.
        if take.edit == nil, Self.sameCuts(start.timeline, left.timeline) { start.timeline = left.timeline }
        return left == start ? nil : draft
    }

    func saveSoon(_ draft: QuickEditDraft, then: @escaping @MainActor @Sendable (QuickEditDraftSaveFailure?) -> Void) {
        do {
            try save(draft)
            then(nil)
        } catch {
            then(QuickEditDraftSaveFailure(error))
        }
    }

    /// The same pieces of the same recording, whatever they are called.
    private static func sameCuts(_ one: EditTimeline, _ other: EditTimeline) -> Bool {
        guard one.sourceDuration == other.sourceDuration, one.isArranged == other.isArranged, one.otherSources == other.otherSources,
              one.segments.count == other.segments.count else { return false }
        return zip(one.segments, other.segments).allSatisfy { piece, kept in
            var renamed = piece
            renamed.id = kept.id
            return renamed == kept
        }
    }
}
