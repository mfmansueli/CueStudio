//
//  IdeaIngredientStore.swift
//  Cue Studio
//

import Foundation

/// The ingredients of each of the creator's topics in each language (`IdeaIngredients`), kept on this iPhone for a week: asked of Private Cloud
/// Compute once a week a topic (about two seconds each), they season the ideas the iPhone's model writes, one subject to each idea, in turn within
/// each kind so the next batch is about something else. Where Private Cloud Compute can't write (off, unavailable, offline, a language it doesn't
/// write), there are none and the ideas are asked as they were before; a topic that got no answer is asked again only an hour later.
@MainActor
final class IdeaIngredientStore {
    private struct Entry: Codable {
        /// The language and the topic, as `key(for:in:)` writes them.
        var key: String
        var ingredients: IdeaIngredients
        var written: Date
        /// How many subjects of each kind went into ideas: the next is the one after.
        var turns: [IdeaIngredientKind: Int] = [:]
    }

    /// How long a topic's ingredients are used before they are asked again.
    static let freshFor: TimeInterval = 7 * 24 * 60 * 60
    /// How long a topic whose ingredients didn't come waits before they are asked again.
    static let retryAfter: TimeInterval = 60 * 60
    /// Most topics (in all languages) kept: the ones written longest ago go first.
    static let capacity = 24

    private var entries: [Entry] = []
    private var failures: [String: Date] = [:]
    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: DefaultsKey.ideaIngredients), let stored = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = stored
        }
    }

    /// Among `topics`, the ones whose ingredients in `language` (for `creator`) are missing or a week old, and weren't asked for in the last hour
    /// without an answer.
    func due(_ topics: [IdeaTopic], in language: CueLanguage, for creator: IdeaCreator? = nil) -> [IdeaTopic] {
        let date = now()
        var due: [IdeaTopic] = []
        for topic in topics where !due.contains(topic) {
            let key = Self.key(for: topic, in: language, creator: creator)
            if let failed = failures[key], date.timeIntervalSince(failed) < Self.retryAfter { continue }
            guard let entry = entries.first(where: { $0.key == key }) else {
                due.append(topic)
                continue
            }
            if date.timeIntervalSince(entry.written) >= Self.freshFor { due.append(topic) }
        }
        return due
    }

    /// What Private Cloud Compute wrote for `topic` in `language`, in place of what was kept; nothing usable counts as no answer.
    func keep(_ ingredients: IdeaIngredients, for topic: IdeaTopic, in language: CueLanguage, creator: IdeaCreator? = nil) {
        let key = Self.key(for: topic, in: language, creator: creator)
        guard !ingredients.isEmpty else {
            noteFailure(for: topic, in: language, creator: creator)
            return
        }
        failures[key] = nil
        entries.removeAll { $0.key == key }
        entries.append(Entry(key: key, ingredients: ingredients, written: now()))
        entries = Array(entries.sorted { $0.written < $1.written }.suffix(Self.capacity))
        persist()
    }

    func noteFailure(for topic: IdeaTopic, in language: CueLanguage, creator: IdeaCreator? = nil) {
        failures[Self.key(for: topic, in: language, creator: creator)] = now()
    }

    /// `slots` with a subject each from its topic's ingredients of the kind its angle takes (`IdeaIngredientKind`), the next one of that kind in
    /// turn. A slot tied to something else (an occasion, a video, a comment: `IdeaSlot.tie`) is about that, one joining two topics is about the
    /// two (`IdeaSlot.bridge`), one left open finds its own way (`IdeaSlot.isOpen`), and a topic without ingredients stays as it was: the old
    /// ones are still used while new ones are asked for.
    func seasoned(_ slots: [IdeaSlot], in language: CueLanguage, for creator: IdeaCreator? = nil) -> [IdeaSlot] {
        var changed = false
        let seasoned = slots.map { slot -> IdeaSlot in
            guard slot.tie == nil, slot.bridge == nil, !slot.isOpen, slot.subject == nil,
                  let index = entries.firstIndex(where: { $0.key == Self.key(for: slot.topic, in: language, creator: creator) })
            else { return slot }
            let kind = IdeaIngredientKind(angle: slot.angle)
            let subjects = entries[index].ingredients.subjects(kind)
            guard !subjects.isEmpty else { return slot }
            let turn = entries[index].turns[kind, default: 0]
            entries[index].turns[kind] = turn + 1
            changed = true
            var slot = slot
            slot.subject = subjects[turn % subjects.count]
            return slot
        }
        if changed { persist() }
        return seasoned
    }

    /// The topic as the model reads it, with what the creator covers inside it (other subtopics are another topic's ingredients) and who they are
    /// and what for, when they said (a lawyer's ingredients are not a student's).
    private static func key(for topic: IdeaTopic, in language: CueLanguage, creator: IdeaCreator?) -> String {
        ([language.rawValue, topic.name] + topic.subtopics + [creator?.promptLine].compactMap { $0 }).joined(separator: "|")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: DefaultsKey.ideaIngredients) }
    }
}
