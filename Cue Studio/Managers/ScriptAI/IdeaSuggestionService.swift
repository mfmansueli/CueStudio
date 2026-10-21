//
//  IdeaSuggestionService.swift
//  Cue Studio
//

import Foundation

/// The ideas Cue suggests: the one on the card in Scripts while its field is empty (and the ones "↻ another idea" brings after it), and the ones
/// Find inspiration shows, one card at a time, for all the creator's topics or one of them. A creator taps until an idea is one they would film, so
/// what the ideas must be is: never the same few, about what they make, in the direction of what they have been writing, and quick. The model writes
/// them as whole briefs (a headline, the angle to take and an opening line, `IdeaBrief`) six at a time, ahead of the taps and kept between sessions;
/// the creator's own notes in the Logbook are what the ideas grow from and come up on the card in their own words; and what they pass, pick and
/// write decides what is asked for next (`IdeaTaste`). The starters (`ThemeCatalog`) are what shows until the first ideas arrive, and all there is
/// without Apple Intelligence.
///
/// The card and Find inspiration share one pool, one taste and one memory: an idea shown in one is not shown again in the other, and what the
/// creator does with an idea in either teaches both. Browsing never waits for the model: the next card is always one already here, and a topic's
/// next six are asked for while a few are still ahead. Ideas run on the same model as scripts, so a refill never starts while the creator waits for
/// something else and stands aside when a script begins (`IdeaRequestPriority`); it is asked for again once the model is free.
@MainActor
@Observable
final class IdeaSuggestionService {
    /// What stays between sessions: the ideas not yet shown are there when the app opens, for the topics they were written for.
    private struct Stored: Codable {
        var signature: String
        var pool: [ThemeIdea]
        var position: Int
        var seen: [String]
        /// The ideas shown, with their angle and opening line (`IdeaEcho`); absent in what older versions kept.
        var echoes: [IdeaEcho]?
        var round: Int
        var taste: IdeaTaste?
    }

    /// Fewer ideas than this ahead of the one shown (on the card, or for the topic Find inspiration is showing), and the next six are asked for: a
    /// creator who taps fast never reaches the end. A batch takes seconds on an iPhone; reading a card takes a few.
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
    /// The ideas used up or shown, as what tells a repeat (`IdeaSimilarity.repeats`): their title, angle and opening line.
    private var echoes: [IdeaEcho] = []
    /// How many batches were asked for these topics: each starts further along the angles and the topics.
    private var round = 0
    private var signature = ""

    // The refills: one at a time (the model answers one request at a time), the others in line.
    private var task: Task<Void, Never>?
    /// Which refill `task` is, so that one that ended after the topics changed doesn't touch the next.
    private var taskToken: UUID?
    private var taskFilter: IdeaTopicFilter?
    private var pendingFilters: [IdeaTopicFilter] = []
    /// Waits for the model to be free (a script is being written) before the refills in line start.
    private var busyWait: Task<Void, Never>?

    // Find inspiration, for this session.
    /// The card each filter shows: it stays until the creator asks for another, even when new ideas arrive under it.
    private var displayed: [IdeaTopicFilter: ThemeIdea] = [:]
    /// Filters whose creator asked for another with nothing left: the card stays, the next one comes when the refill does.
    private var waitingFilters: Set<IdeaTopicFilter> = []
    /// Filters whose last refill failed: the creator is told and can try again (`retry(in:)`).
    private var failedFilters: Set<IdeaTopicFilter> = []
    /// Starters already shown (`ThemeIdea.id`): they come once, and again only when there is nothing else.
    private var shownStarters: Set<String> = []

    private let writer: ScriptWriting
    private let profile: CreatorProfileService
    private let interfaceLanguage: () -> CueLanguage?
    private let inspiration: () -> [String]
    private let notes: () -> [LogbookEntry]
    private let defaults: UserDefaults
    /// How often a refill that waits for the model looks again whether it is free.
    var busyRetry: Duration = .milliseconds(600)

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

    /// The idea suggested now: a note of theirs when it is its turn, else the next of the model's, else a starter about their topics.
    var current: ThemeIdea? {
        if let logbookCard { return logbookCard }
        if position < pool.count { return pool[position] }
        return starter
    }

    /// The ideas the model wrote that the card hasn't shown yet, kept on this iPhone: the only ideas a notification may say exist.
    var unseenModelIdeas: [ThemeIdea] {
        pool.indices.filter { $0 > position || ($0 == position && logbookCard != nil) }.map { pool[$0] }.filter { $0.angle != nil }
    }

    /// The idea a notification named (`IdeaKey`), if Cue still has it.
    func idea(forKey key: String) -> ThemeIdea? {
        pool.first { IdeaKey.of($0) == key }
    }

    private var starter: ThemeIdea? {
        let starters = ThemeCatalog.ideas(for: profile.profile.ideaTopics)
        guard !starters.isEmpty else { return nil }
        return starters[(starterRotation % starters.count + starters.count) % starters.count]
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
        } else if position < pool.count, isFetching {
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
        ensureRefill(for: .all)
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
        ensureRefill(for: .all)
    }

    // MARK: - Find inspiration (the roulette)
    //
    // Three things the creator does with an idea are told apart (`IdeaTaste`): passing it ("Another idea"), picking it to change ("Start with it"),
    // and a script written from it (`generated(from:)`, through `ScriptStarter`).

    /// The idea the roulette shows for `filter`: the one it showed last, else the next one ready about it (the model's first, then a starter about
    /// it). Nil only while the first ideas are on their way with nothing else to show (`isWaiting(in:)`), or after they failed (`refillFailed(in:)`).
    func current(in filter: IdeaTopicFilter) -> ThemeIdea? {
        if let shown = displayed[filter], isStillShowable(shown, in: filter) { return shown }
        return next(in: filter, excluding: nil)
    }

    /// "Another idea": the creator passed the one shown (a light signal), and the next comes at once from what is ready; the model is never asked
    /// for one card. With nothing left, the card stays and the next comes with the refill (`isWaiting(in:)`).
    func another(in filter: IdeaTopicFilter) {
        refreshIfTopicsChanged()
        failedFilters.remove(filter)
        guard !waitingFilters.contains(filter) else { return ensureRefill(for: filter) }
        let shown = current(in: filter)
        if let shown {
            if shown.angle != nil || shown.brief?.angleKind != nil { taste.passed(shown) }
            consume(shown)
        }
        if let next = next(in: filter, excluding: shown) {
            show(next, in: filter)
        } else {
            displayed[filter] = shown
            if canAskModel { waitingFilters.insert(filter) }
        }
        persist()
        ensureRefill(for: filter)
    }

    /// Find inspiration is open on `filter`: its card is chosen, and ideas about it are ready before they are asked for.
    func prepare(for filter: IdeaTopicFilter) {
        refreshIfTopicsChanged()
        if displayed[filter].map({ !isStillShowable($0, in: filter) }) ?? true {
            displayed[filter] = nil
            if let next = next(in: filter, excluding: nil) {
                show(next, in: filter)
            } else if canAskModel {
                waitingFilters.insert(filter)
            }
        }
        ensureRefill(for: filter)
    }

    /// The next ideas for `filter` are on their way and there is no new one to show yet: the card that is there stays (or a placeholder, when
    /// there is none).
    func isWaiting(in filter: IdeaTopicFilter) -> Bool {
        if waitingFilters.contains(filter) { return true }
        return current(in: filter) == nil && isFetching
    }

    /// The last ideas asked for `filter` didn't come (the model failed, or brought only ideas already shown): "Couldn't get new ideas · Try again".
    func refillFailed(in filter: IdeaTopicFilter) -> Bool {
        failedFilters.contains(filter)
    }

    /// "Try again" after `refillFailed(in:)`: the next ideas are asked for now, and the card waits for them.
    func retry(in filter: IdeaTopicFilter) {
        refreshIfTopicsChanged()
        failedFilters.remove(filter)
        guard canAskModel else { return }
        if queued(filter).isEmpty { waitingFilters.insert(filter) }
        ensureRefill(for: filter, evenIfAhead: true)
    }

    /// "Start with it": the creator picked it to change before it is written. Liked, not yet used; it leaves the roulette and the card.
    func selected(_ idea: ThemeIdea) {
        refreshIfTopicsChanged()
        if idea.angle != nil || idea.brief?.angleKind != nil { taste.selected(idea) }
        consume(idea)
        forgetDisplayed(idea)
        persist()
        ensureRefill(for: .all)
    }

    /// A script was written from `brief` (what of it the creator's text still said): the strongest signal there is. The idea it came from, if it is
    /// still here, is not suggested again.
    func generated(from brief: IdeaBrief) {
        taste.generated(brief)
        if let idea = pool.first(where: { $0.brief?.subject == brief.subject }) {
            consume(idea)
            forgetDisplayed(idea)
        }
        persist()
    }

    /// The ideas ready for `filter`, in order: the model's that come after the card's own (the card keeps the one it shows), with a brief.
    private func queued(_ filter: IdeaTopicFilter) -> [ThemeIdea] {
        guard position + 1 < pool.count else { return [] }
        return pool[(position + 1)...].filter { $0.brief != nil && filter.includes($0) }
    }

    /// The starters about `filter`: the topic's own (or ones made from its name), or all the creator's topics' in turn.
    private func starters(for filter: IdeaTopicFilter) -> [ThemeIdea] {
        switch filter {
        case .all: ThemeCatalog.ideas(for: profile.profile.ideaTopics)
        case .topic(let topic): ThemeCatalog.ideas(for: topic)
        }
    }

    /// The next idea for `filter` that isn't `shown`: the model's first, then a starter not shown yet; with the model, an end of the starters is
    /// a wait for its ideas, and without it the starters go round again.
    private func next(in filter: IdeaTopicFilter, excluding shown: ThemeIdea?) -> ThemeIdea? {
        if let idea = queued(filter).first(where: { $0 != shown }) { return idea }
        let starters = starters(for: filter)
        if let idea = starters.first(where: { !shownStarters.contains($0.id) && $0 != shown }) { return idea }
        guard !canAskModel, !starters.isEmpty else { return nil }
        let after = shown.flatMap { starters.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        return starters[after % starters.count]
    }

    private func show(_ idea: ThemeIdea, in filter: IdeaTopicFilter) {
        displayed[filter] = idea
        waitingFilters.remove(filter)
        if idea.angle == nil { shownStarters.insert(idea.id) }
        taste.showed(idea)
    }

    /// Whether the card a filter showed can still be shown: a starter, an idea still ahead in the pool, or the last one while the next are coming.
    private func isStillShowable(_ idea: ThemeIdea, in filter: IdeaTopicFilter) -> Bool {
        idea.angle == nil || waitingFilters.contains(filter) || queued(filter).contains(idea)
    }

    /// The idea is used up: out of the pool (remembered by its title, angle and opening line, so it never comes back in other words), or a
    /// starter not to show again.
    private func consume(_ idea: ThemeIdea) {
        guard idea.angle != nil else {
            shownStarters.insert(idea.id)
            return
        }
        guard let index = pool.firstIndex(of: idea), index >= position else { return }
        pool.remove(at: index)
        seen.append(idea.title)
        echoes.append(IdeaEcho(idea))
    }

    private func forgetDisplayed(_ idea: ThemeIdea) {
        for filter in displayed.keys where displayed[filter] == idea {
            displayed[filter] = nil
            waitingFilters.remove(filter)
        }
    }

    // MARK: - The model's ideas

    private var canAskModel: Bool { writer.isEnabled && writer.availability.isAvailable }

    /// A refill is under way or in line.
    private var isFetching: Bool { isRefilling || task != nil || busyWait != nil }

    /// Whether `filter` has fewer ideas ahead than `lowWater`. The card counts every idea after the one it shows.
    private func needsRefill(_ filter: IdeaTopicFilter) -> Bool {
        switch filter {
        case .all: pool.count - position <= Self.lowWater || queued(.all).count < Self.lowWater
        case .topic: queued(filter).count < Self.lowWater
        }
    }

    /// Asks for the next ideas about `filter` when few are ahead: now when the model is free, else once it is. One refill runs at a time.
    private func ensureRefill(for filter: IdeaTopicFilter, evenIfAhead: Bool = false) {
        guard canAskModel, evenIfAhead || needsRefill(filter) else { return }
        guard task == nil, busyWait == nil else {
            if taskFilter != filter, !pendingFilters.contains(filter) { pendingFilters.append(filter) }
            return
        }
        // A script (or a rewrite, hooks) is being written: the ideas wait for it to end instead of slowing it down.
        guard !writer.isBusyForeground else {
            if !pendingFilters.contains(filter) { pendingFilters.append(filter) }
            waitUntilFree()
            return
        }
        start(filter)
    }

    private func start(_ filter: IdeaTopicFilter) {
        let priority: IdeaRequestPriority = waitingFilters.contains(filter) || current(in: filter) == nil ? .waiting : .prefetch
        let token = UUID()
        taskToken = token
        taskFilter = filter
        task = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.refill(for: filter, priority: priority)
            guard self.taskToken == token else { return }
            self.task = nil
            self.taskToken = nil
            self.taskFilter = nil
            self.finish(filter, outcome)
        }
    }

    /// What a refill came to.
    private enum Outcome {
        case added, nothingNew, failed, cancelled, stale
    }

    private func finish(_ filter: IdeaTopicFilter, _ outcome: Outcome) {
        switch outcome {
        case .added:
            break
        case .cancelled:
            // A script began: the same ideas are asked for once it ends.
            if !pendingFilters.contains(filter) { pendingFilters.insert(filter, at: 0) }
            waitUntilFree()
            return
        case .stale:
            return
        case .nothingNew, .failed:
            // Only a creator who is looking at nothing new is told: a refill fetched ahead that failed is asked for again later.
            if waitingFilters.contains(filter) || current(in: filter) == nil { failedFilters.insert(filter) }
        }
        resolveWaiting()
        startNextPending()
    }

    /// The ideas a creator waited for are here: the card shows the next, and so does every filter that waited. A filter still with nothing new,
    /// and nothing more on its way, stops waiting and says the ideas didn't come.
    private func resolveWaiting() {
        if isWaiting {
            isWaiting = false
            if position + 1 < pool.count { position += 1 }
            persist()
        }
        for filter in waitingFilters {
            if let next = next(in: filter, excluding: displayed[filter]) {
                show(next, in: filter)
            } else if !pendingFilters.contains(filter), taskFilter != filter {
                waitingFilters.remove(filter)
                failedFilters.insert(filter)
            }
        }
    }

    private func startNextPending() {
        while task == nil, busyWait == nil, !pendingFilters.isEmpty {
            let filter = pendingFilters.removeFirst()
            if waitingFilters.contains(filter) || needsRefill(filter) { ensureRefill(for: filter, evenIfAhead: true) }
        }
    }

    /// Looks again every `busyRetry` until the model is free, then starts the refills in line.
    private func waitUntilFree() {
        guard busyWait == nil else { return }
        busyWait = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.writer.isBusyForeground { break }
                try? await Task.sleep(for: self.busyRetry)
            }
            guard let self, !Task.isCancelled else { return }
            self.busyWait = nil
            self.startNextPending()
        }
    }

    /// Six ideas about the creator's topics (all of them, for the card and "All my topics"), in the direction of what they have been writing, that
    /// none of the ones already shown repeat. A failure leaves things as they were: the starters stay.
    func refill() async {
        let outcome = await refill(for: .all, priority: .waiting)
        if outcome == .added || outcome == .nothingNew || outcome == .failed { resolveWaiting() }
    }

    /// Six ideas about `filter`'s topics (one topic's six when Find inspiration shows one). The model may bring ideas it already brought in other
    /// words: one more look from other angles when too few are new.
    private func refill(for filter: IdeaTopicFilter, priority: IdeaRequestPriority) async -> Outcome {
        guard !isRefilling else { return .stale }
        isRefilling = true
        defer { isRefilling = false }
        let asked = signature
        let language = interfaceLanguage()
        let voice = profile.writesInMyVoice ? profile.profile.voice(inLanguage: language?.locale.language.languageCode?.identifier) : nil
        // What came before, by title alone for what an older version kept, by title, angle and opening line for the rest.
        let known = seen.filter { title in !echoes.contains { $0.title == IdeaSimilarity.words(in: title) } }.map(IdeaEcho.init(title:))
            + echoes + pool.map(IdeaEcho.init)
        let topics: [IdeaTopic] = switch filter {
        case .all: profile.profile.ideaTopics.isEmpty ? [.lifestyle] : profile.profile.ideaTopics
        case .topic(let topic): [topic]
        }
        var new: [ThemeIdea] = []
        var failed = false
        for _ in 0..<2 where new.count < 4 {
            let slots = taste.slots(round: round, among: topics)
            round += 1
            let fresh: [ThemeIdea]
            do {
                fresh = try await writer.suggestIdeas(
                    slots: slots, language: language, voice: voice, inspiration: inspiration(), priority: priority
                )
            } catch is CancellationError {
                return asked == signature ? .cancelled : .stale
            } catch {
                failed = true
                break
            }
            guard !Task.isCancelled else { return asked == signature ? .cancelled : .stale }
            guard asked == signature else { return .stale }
            // A brief with two weaknesses is no idea (`IdeaSpecificity`); one that repeats another, here or before, is the same idea twice. The
            // ones with a weakness come after the others of the batch.
            var taken = known + new.map(IdeaEcho.init)
            var kept: [ThemeIdea] = []
            for idea in fresh where !IdeaSpecificity.isUnusable(idea) {
                let echo = IdeaEcho(idea)
                guard !taken.contains(where: { IdeaSimilarity.repeats(echo, $0) }) else { continue }
                taken.append(echo)
                kept.append(idea)
            }
            new += kept.filter { IdeaSpecificity.weaknesses(of: $0).isEmpty } + kept.filter { !IdeaSpecificity.weaknesses(of: $0).isEmpty }
        }
        guard !new.isEmpty else { return failed ? .failed : .nothingNew }
        pool.append(contentsOf: new)
        // The ones already shown are only remembered by what tells a repeat (`IdeaEcho`).
        if position > Self.lowWater * 3 {
            seen += pool.prefix(position).map(\.title)
            echoes += pool.prefix(position).map(IdeaEcho.init)
            pool.removeFirst(position)
            position = 0
        }
        seen = Array(seen.suffix(Self.memory))
        echoes = Array(echoes.suffix(Self.memory))
        persist()
        return .added
    }

    // MARK: - Topics changed

    /// What the ideas were written for: the topics with their subtopics, the language they are in and whether they are in the creator's voice.
    private var currentSignature: String {
        let topics = profile.profile.ideaTopics.map { "\($0.name)(\($0.subtopics.joined(separator: ",")))" }.joined(separator: ";")
        return [topics, interfaceLanguage()?.rawValue ?? "", profile.writesInMyVoice ? "voice" : "plain"].joined(separator: "|")
    }

    /// Other topics, language or voice make the ideas written before about something else: they go, what was being asked for is cancelled, and
    /// the next six are asked for. What the creator likes stays: their taste for an angle is theirs, whatever the topic.
    private func refreshIfTopicsChanged() {
        let now = currentSignature
        guard now != signature else { return }
        clear(signature: now)
        persist()
    }

    /// "Delete my Cue data": the ideas written for the creator and the taste Cue learned from them go too.
    func forgetEverything() {
        clear(signature: currentSignature)
        taste = IdeaTaste()
        defaults.removeObject(forKey: DefaultsKey.ideaSuggestions)
    }

    /// Nothing asked for or written any more, under `signature`.
    private func clear(signature now: String) {
        task?.cancel()
        task = nil
        taskToken = nil
        taskFilter = nil
        busyWait?.cancel()
        busyWait = nil
        pendingFilters = []
        signature = now
        pool = []
        position = 0
        seen = []
        echoes = []
        round = 0
        logbookCard = nil
        isWaiting = false
        displayed = [:]
        waitingFilters = []
        failedFilters = []
    }

    // MARK: - Memory

    private func persist() {
        let stored = Stored(signature: signature, pool: pool, position: position, seen: seen, echoes: echoes, round: round, taste: taste)
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: DefaultsKey.ideaSuggestions) }
    }

    private func restore() {
        guard let data = defaults.data(forKey: DefaultsKey.ideaSuggestions), let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        taste = stored.taste ?? IdeaTaste()
        guard stored.signature == signature else { return }
        pool = stored.pool
        position = min(stored.position, stored.pool.count)
        seen = stored.seen
        echoes = stored.echoes ?? []
        round = stored.round
    }
}
