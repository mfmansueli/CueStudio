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

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        let stored = defaults.data(forKey: DefaultsKey.logbook).flatMap { try? JSONDecoder().decode([LogbookEntry].self, from: $0) }
        entries = stored ?? []
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

    func delete(_ id: UUID) {
        delete([id])
    }

    /// Takes these ideas away and returns them as they were, for an Undo (`restore`).
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

    private func persist() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: DefaultsKey.logbook)
    }
}
