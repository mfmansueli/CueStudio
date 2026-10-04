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
        entries.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: DefaultsKey.logbook)
    }
}
