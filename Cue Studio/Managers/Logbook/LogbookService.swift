//
//  LogbookService.swift
//  Cue Studio
//

import Foundation

/// The Logbook: ideas caught now, shaped later. Kept on this iPhone. A spoken idea is only its words (the recognition
/// runs on the iPhone and no sound is kept).
@MainActor
@Observable
final class LogbookService {
    private(set) var entries: [LogbookEntry]
    /// What was left in the field, typed or heard, when the Logbook closed: there again the next time, as in Messages.
    private(set) var draft: String

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        let stored = defaults.data(forKey: DefaultsKey.logbook).flatMap { try? JSONDecoder().decode([LogbookEntry].self, from: $0) }
        entries = stored ?? []
        draft = defaults.string(forKey: DefaultsKey.logbookDraft) ?? ""
    }

    /// The field's words as the Logbook closes (blank words keep nothing).
    func keepDraft(_ text: String) {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : text
        guard words != draft else { return }
        draft = words
        if words.isEmpty { defaults.removeObject(forKey: DefaultsKey.logbookDraft) } else { defaults.set(words, forKey: DefaultsKey.logbookDraft) }
    }

    /// The ideas still waiting, newest first.
    var waiting: [LogbookEntry] { entries.filter(\.isWaiting) }

    /// Catches an idea. Blank words are ignored. Returns the entry, nil when there was nothing to keep.
    @discardableResult
    func add(_ text: String, spokenSeconds: Int? = nil) -> LogbookEntry? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        let entry = LogbookEntry(text: words, spokenSeconds: spokenSeconds, createdAt: now())
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    /// An audience comment about to be answered (`ScriptStarter.keepsComment`): kept as a waiting idea ("@maya: …"), or the same words
    /// already waiting (a second try never makes a copy). Nil when it couldn't be kept: the toast says "Saved to Logbook" only when it is there.
    func keep(_ comment: ScriptComment) -> (note: UUID, isNew: Bool)? {
        let words = (comment.author.map { "\($0): \(comment.text)" } ?? comment.text).trimmingCharacters(in: .whitespacesAndNewlines)
        if let waiting = waiting.first(where: { $0.text == words }) { return (waiting.id, false) }
        guard let entry = add(words), entries.contains(where: { $0.id == entry.id }) else { return nil }
        return (entry.id, true)
    }

    /// The comment's reply was written: the note made for it goes (the comment is on the script); one that was waiting before is shaped into it,
    /// like an idea written from the Logbook.
    func answered(_ kept: (note: UUID, isNew: Bool), as scriptID: UUID) {
        if kept.isNew {
            delete([kept.note])
        } else {
            markShaped(kept.note, as: scriptID)
        }
    }

    /// The creator corrected an idea (a word misheard, a better angle): it keeps its place, its day and how it came in. Blank words change
    /// nothing. Returns the idea as it is now, nil when there is none.
    @discardableResult
    func edit(_ id: UUID, text: String) -> LogbookEntry? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty, let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        if entries[index].text != words {
            entries[index].text = words
            persist()
        }
        return entries[index]
    }

    func setTopic(_ topic: String?, of id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }), entries[index].topic != topic else { return }
        entries[index].topic = topic
        persist()
    }

    func markShaped(_ id: UUID, as scriptID: UUID?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].shapedScriptID = scriptID ?? entries[index].id
        persist()
    }

    /// Takes these ideas away for good and returns them as they were, for the toast's Undo (`restore`).
    @discardableResult
    func delete(_ ids: Set<UUID>) -> [LogbookEntry] {
        let removed = entries.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return [] }
        entries.removeAll { ids.contains($0.id) }
        persist()
        return removed
    }

    /// Puts deleted ideas back where they were, among the others by when each was caught (an Undo).
    func restore(_ restored: [LogbookEntry]) {
        let missing = restored.filter { entry in !entries.contains { $0.id == entry.id } }
        guard !missing.isEmpty else { return }
        entries = (entries + missing).sorted { $0.createdAt > $1.createdAt }
        persist()
    }

    /// "Delete my Cue data": every idea, for good.
    func eraseAll() {
        entries = []
        persist()
        keepDraft("")
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: DefaultsKey.logbook)
    }
}
