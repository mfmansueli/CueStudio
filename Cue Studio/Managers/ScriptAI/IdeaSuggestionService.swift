//
//  IdeaSuggestionService.swift
//  Cue Studio
//

import Foundation

/// The idea the card in Scripts suggests while its field is empty, and the ones "↻ another idea" brings after it. The starter ideas are three for each of
/// the first flight's topics, so a creator with one topic had the same three forever, and one who holds only their own topics (the ones typed in My Cue
/// Voice, the ones only it offers) had the first flight's Lifestyle ones, about nothing they make. The model writes ideas about all of the creator's
/// topics, six at a time and none that came before, in the background, and the card walks through them; the starters are what shows until they arrive.
@MainActor
@Observable
final class IdeaSuggestionService {
    /// What stays between sessions: the ideas not yet shown are there when the app opens, for the topics they were written for.
    private struct Stored: Codable {
        var signature: String
        var pool: [ThemeIdea]
        var position: Int
        var seen: [String]
        var round: Int
    }

    /// Fewer ideas than this ahead of the one shown, and the next six are asked for.
    static let lowWater = 2
    /// The most ideas remembered as shown, to be told to the model so that it brings others.
    static let memory = 60

    private(set) var pool: [ThemeIdea] = []
    private(set) var position = 0
    private(set) var isRefilling = false
    private var starterRotation = 0
    private var seen: [String] = []
    /// How many batches were asked for these topics: each looks at them from other angles (`IdeaAngle`).
    private var round = 0
    private var signature = ""
    private var task: Task<Void, Never>?

    private let writer: ScriptWriting
    private let profile: CreatorProfileService
    private let interfaceLanguage: () -> CueLanguage?
    private let defaults: UserDefaults

    init(writer: ScriptWriting, profile: CreatorProfileService, interfaceLanguage: @escaping () -> CueLanguage?, defaults: UserDefaults = .standard) {
        self.writer = writer
        self.profile = profile
        self.interfaceLanguage = interfaceLanguage
        self.defaults = defaults
        signature = currentSignature
        restore()
    }

    // MARK: - What the card shows

    /// The idea suggested now: the next of the model's, else a starter. Nothing for a creator whose topics are all their own while the first six are on
    /// their way: starters about something else would be a suggestion about nothing they make.
    var current: ThemeIdea? {
        if position < pool.count { return pool[position] }
        return starter
    }

    private var starter: ThemeIdea? {
        let topics = profile.profile.ideaTopics
        if topics.isEmpty { return ThemeCatalog.page(for: [], rotation: starterRotation).first }
        let niches = topics.compactMap(\.niche)
        return niches.isEmpty ? nil : ThemeCatalog.page(for: niches, rotation: starterRotation).first
    }

    /// "↻": the next idea; and the next six on their way when few are left.
    func another() {
        refreshIfTopicsChanged()
        if position < pool.count { position += 1 } else { starterRotation += 1 }
        persist()
        refillIfLow()
    }

    /// The Scripts screen opened, or the creator's topics changed: ideas are ready before they are asked for.
    func prepare() {
        refreshIfTopicsChanged()
        refillIfLow()
    }

    // MARK: - The model's ideas

    private func refillIfLow() {
        guard task == nil, pool.count - position <= Self.lowWater else { return }
        guard writer.isEnabled, writer.availability.isAvailable, !writer.isBusyForeground else { return }
        task = Task {
            await refill()
            task = nil
        }
    }

    /// Six ideas about the creator's topics that none of the ones already shown repeat. A failure leaves things as they were: the starters stay.
    func refill() async {
        guard !isRefilling else { return }
        isRefilling = true
        defer { isRefilling = false }
        let asked = signature
        let language = interfaceLanguage()
        let voice = profile.writesInMyVoice ? profile.profile.voice(inLanguage: language?.locale.language.languageCode?.identifier) : nil
        let avoiding = seen + pool.map(\.title)
        let topics = profile.profile.ideaTopics
        var new: [ThemeIdea] = []
        // The model may bring ideas it already brought in other words: one more look from other angles when too few are new.
        for _ in 0..<2 where new.count < 4 {
            let asking = round
            round += 1
            guard let fresh = try? await writer.suggestIdeas(
                about: topics, language: language, voice: voice, avoiding: avoiding + new.map(\.title), round: asking
            ), asked == signature else { return }
            let known = (avoiding + new.map(\.title)).map(IdeaSimilarity.words(in:))
            new += fresh.filter { idea in
                let words = IdeaSimilarity.words(in: idea.title)
                return !known.contains { IdeaSimilarity.areAlike($0, words) }
            }
        }
        guard !new.isEmpty else { return }
        pool.append(contentsOf: new)
        // The ones already shown are only remembered by their titles.
        if position > Self.lowWater * 3 {
            seen += pool.prefix(position).map(\.title)
            pool.removeFirst(position)
            position = 0
            seen = Array(seen.suffix(Self.memory))
        }
        persist()
    }

    // MARK: - Topics changed

    /// What the ideas were written for: the topics with their subtopics, the language they are in and whether they are in the creator's voice.
    private var currentSignature: String {
        let topics = profile.profile.ideaTopics.map { "\($0.name)(\($0.subtopics.joined(separator: ",")))" }.joined(separator: ";")
        return [topics, interfaceLanguage()?.rawValue ?? "", profile.writesInMyVoice ? "voice" : "plain"].joined(separator: "|")
    }

    /// Other topics, language or voice make the ideas written before about something else: they go, and the next six are asked for.
    private func refreshIfTopicsChanged() {
        let now = currentSignature
        guard now != signature else { return }
        task?.cancel()
        task = nil
        signature = now
        pool = []
        position = 0
        seen = []
        round = 0
        persist()
    }

    // MARK: - Memory

    private func persist() {
        let stored = Stored(signature: signature, pool: pool, position: position, seen: seen, round: round)
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: DefaultsKey.ideaSuggestions) }
    }

    private func restore() {
        guard let data = defaults.data(forKey: DefaultsKey.ideaSuggestions), let stored = try? JSONDecoder().decode(Stored.self, from: data),
              stored.signature == signature else { return }
        pool = stored.pool
        position = min(stored.position, stored.pool.count)
        seen = stored.seen
        round = stored.round
    }
}
