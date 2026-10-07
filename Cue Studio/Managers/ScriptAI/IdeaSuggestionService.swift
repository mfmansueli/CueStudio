//
//  IdeaSuggestionService.swift
//  Cue Studio
//

import Foundation

/// The idea the card in Scripts suggests while its field is empty, and the ones "↻ another idea" brings after it. A creator taps "↻" until an idea is
/// one they would film, so what the card must be is: never the same few, about what they make, in the direction of what they have been writing, and
/// quick. The starter ideas were three for each of the first flight's topics (a creator with one topic had the same three forever, and one who holds
/// only their own had Lifestyle's). Now the model writes ideas about all the creator's topics, six at a time, ahead of the taps and kept between
/// sessions; the creator's own notes in the Logbook are what the ideas grow from and come up among them in their own words; and what they pass and what
/// they send decides what is asked for next (`IdeaTaste`). The starters are what shows until the first ideas arrive.
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
        var taste: IdeaTaste?
    }

    /// Fewer ideas than this ahead of the one shown, and the next six are asked for: a creator who taps fast never reaches the end.
    static let lowWater = 4
    /// The most ideas remembered as shown, to be told apart from the new ones.
    static let memory = 60
    /// A note from the Logbook comes up after this many ideas of the model's.
    static let logbookEvery = 4

    private(set) var pool: [ThemeIdea] = []
    private(set) var position = 0
    private(set) var isRefilling = false
    /// "↻" was tapped at the end of the ideas and the next are on their way: the card waits instead of showing something else.
    private(set) var isWaiting = false
    private(set) var taste = IdeaTaste()
    /// A note of the creator's own that the card shows now, between the model's ideas.
    private var logbookCard: ThemeIdea?
    private var shownLogbook: Set<UUID> = []
    private var sinceLogbook = 0
    private var starterRotation = 0
    private var seen: [String] = []
    /// How many batches were asked for these topics: each starts further along the angles and the topics.
    private var round = 0
    private var signature = ""
    private var task: Task<Void, Never>?

    private let writer: ScriptWriting
    private let profile: CreatorProfileService
    private let interfaceLanguage: () -> CueLanguage?
    private let inspiration: () -> [String]
    private let notes: () -> [LogbookEntry]
    private let defaults: UserDefaults

    /// - Parameters:
    ///   - inspiration: what the creator wrote lately (the titles of their latest scripts and their notes), the ideas grow from it.
    ///   - notes: the ideas waiting in their Logbook, which come up among the model's.
    init(
        writer: ScriptWriting, profile: CreatorProfileService, interfaceLanguage: @escaping () -> CueLanguage?,
        inspiration: @escaping () -> [String] = { [] }, notes: @escaping () -> [LogbookEntry] = { [] }, defaults: UserDefaults = .standard
    ) {
        self.writer = writer
        self.profile = profile
        self.interfaceLanguage = interfaceLanguage
        self.inspiration = inspiration
        self.notes = notes
        self.defaults = defaults
        signature = currentSignature
        restore()
    }

    // MARK: - What the card shows

    /// The idea suggested now: a note of theirs when it is its turn, else the next of the model's, else a starter. Nothing for a creator whose topics are
    /// all their own while the first six are on their way: starters about something else would be a suggestion about nothing they make.
    var current: ThemeIdea? {
        if let logbookCard { return logbookCard }
        if position < pool.count { return pool[position] }
        return starter
    }

    private var starter: ThemeIdea? {
        let topics = profile.profile.ideaTopics
        if topics.isEmpty { return ThemeCatalog.page(for: [], rotation: starterRotation).first }
        let niches = topics.compactMap(\.niche)
        return niches.isEmpty ? nil : ThemeCatalog.page(for: niches, rotation: starterRotation).first
    }

    /// "↻": the creator passed this idea; the next one, and the next six on their way when few are left.
    func another() {
        refreshIfTopicsChanged()
        if let shown = current, logbookCard == nil, shown.angle != nil { taste.passed(shown) }
        advance()
    }

    /// The creator sent the idea on the card: it is what they like, and the card brings the next. Returns the note it was, when it was one of theirs.
    @discardableResult
    func sent() -> UUID? {
        refreshIfTopicsChanged()
        let note = logbookCard?.logbookID
        if let shown = current, note == nil, shown.angle != nil { taste.sent(shown) }
        advance()
        return note
    }

    private func advance() {
        if logbookCard != nil {
            logbookCard = nil
        } else if position + 1 < pool.count {
            position += 1
            sinceLogbook += 1
        } else if position < pool.count, isRefilling || task != nil {
            // The last one is on the card and more are coming: wait for them rather than go back to starters.
            isWaiting = true
        } else if position < pool.count {
            position += 1
        } else {
            starterRotation += 1
        }
        if logbookCard == nil, sinceLogbook >= Self.logbookEvery, let note = nextNote() {
            logbookCard = note
            sinceLogbook = 0
        }
        if let shown = current { taste.showed(shown) }
        persist()
        refillIfLow()
    }

    /// The next note of theirs not shown yet this session.
    private func nextNote() -> ThemeIdea? {
        guard let entry = notes().first(where: { !shownLogbook.contains($0.id) }) else { return nil }
        shownLogbook.insert(entry.id)
        var idea = ThemeIdea(title: String(entry.text.prefix(160)), kind: "", length: .minute1, niche: .lifestyle)
        idea.logbookID = entry.id
        return idea
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
            // The creator was at the end when it arrived: the idea they waited for is on the card.
            if isWaiting {
                isWaiting = false
                if position + 1 < pool.count { position += 1 }
                persist()
            }
        }
    }

    /// Six ideas about the creator's topics, in the direction of what they have been writing, that none of the ones already shown repeat. A failure
    /// leaves things as they were: the starters stay.
    func refill() async {
        guard !isRefilling else { return }
        isRefilling = true
        defer { isRefilling = false }
        let asked = signature
        let language = interfaceLanguage()
        let voice = profile.writesInMyVoice ? profile.profile.voice(inLanguage: language?.locale.language.languageCode?.identifier) : nil
        let known = (seen + pool.map(\.title)).map(IdeaSimilarity.words(in:))
        var new: [ThemeIdea] = []
        // The model may bring ideas it already brought in other words: one more look from other angles when too few are new.
        for _ in 0..<2 where new.count < 4 {
            let held = profile.profile.ideaTopics
            let slots = taste.slots(round: round, among: held.isEmpty ? [.lifestyle] : held)
            round += 1
            guard let fresh = try? await writer.suggestIdeas(slots: slots, language: language, voice: voice, inspiration: inspiration()),
                  asked == signature else { return }
            let taken = known + new.map { IdeaSimilarity.words(in: $0.title) }
            new += fresh.filter { idea in
                let words = IdeaSimilarity.words(in: idea.title)
                return !taken.contains { IdeaSimilarity.areAlike($0, words) }
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

    /// Other topics, language or voice make the ideas written before about something else: they go, and the next six are asked for. What the creator
    /// likes stays: their taste for an angle is theirs, whatever the topic.
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
        logbookCard = nil
        isWaiting = false
        persist()
    }

    // MARK: - Memory

    private func persist() {
        let stored = Stored(signature: signature, pool: pool, position: position, seen: seen, round: round, taste: taste)
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: DefaultsKey.ideaSuggestions) }
    }

    private func restore() {
        guard let data = defaults.data(forKey: DefaultsKey.ideaSuggestions), let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        taste = stored.taste ?? IdeaTaste()
        guard stored.signature == signature else { return }
        pool = stored.pool
        position = min(stored.position, stored.pool.count)
        seen = stored.seen
        round = stored.round
    }
}
