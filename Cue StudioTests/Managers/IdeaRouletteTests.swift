//
//  IdeaRouletteTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Find inspiration's roulette (`IdeaSuggestionService.current(in:)`, `another(in:)`): the next card is always one already here (the model is never
/// asked for one card), a topic's next ideas are asked for before it runs out, a refill for topics the creator no longer has is cancelled, ideas never
/// make a script wait, and the card and the roulette share what was shown and what was liked.
@MainActor
@Suite("Find inspiration")
struct IdeaRouletteTests {
    private struct Rig {
        let service: IdeaSuggestionService
        let writer: FakeScriptWriter
        let profile: CreatorProfileService
        let defaults: TestDefaults
    }

    private let finance = IdeaTopic(name: Niche.finance.promptName, label: Niche.finance.label, niche: .finance)
    private let travel = IdeaTopic(name: Niche.travel.promptName, label: Niche.travel.label, niche: .travel)

    private func rig(profile edit: (inout CreatorProfile) -> Void = { $0.niches = [.finance, .travel] }) -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var created = profile.profile
        edit(&created)
        profile.profile = created
        let writer = FakeScriptWriter()
        let service = IdeaSuggestionService(writer: writer, profile: profile, interfaceLanguage: { .english }, defaults: defaults.defaults)
        service.busyRetry = .milliseconds(5)
        return Rig(service: service, writer: writer, profile: profile, defaults: defaults)
    }

    /// Ideas as the model's come: a brief each, a different angle each, about `niche` (or a typed topic).
    private func batch(_ prefix: String, count: Int = 6, niche: Niche = .finance, topic: String? = nil) -> [ThemeIdea] {
        (0..<count).map { index in
            let angle = IdeaAngle.allCases[index % IdeaAngle.allCases.count]
            let slot = IdeaSlot(angle: angle, topic: IdeaTopic(name: topic ?? niche.promptName, label: topic ?? niche.label, niche: topic == nil ? niche : nil))
            let answer = IdeaBriefReader.Answer(
                title: "\(prefix) \(Self.words[index % Self.words.count])", angle: "Explain the \(prefix) part.", openingLine: "Here is \(prefix)."
            )
            return IdeaBriefReader.idea(from: answer, slot: slot, language: "en")!
        }
    }

    private static let words = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet", "kilo", "lima"]

    private func settle(_ rig: Rig) async {
        for _ in 0..<200 {
            await Task.yield()
            if !rig.service.isRefilling, !rig.service.isWaiting(in: .all) { try? await Task.sleep(for: .milliseconds(2)) }
        }
    }

    // MARK: - Browsing is instant

    @Test func anotherIdeaShowsTheNextFromWhatIsHereWithoutAskingTheModel() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving", count: 12)]
        await rig.service.refill()
        let asked = rig.writer.suggestionRequests.count
        rig.service.prepare(for: .all)
        var shown: [String] = []
        let clock = ContinuousClock()
        var slowest = Duration.zero
        for _ in 0..<6 {
            guard let idea = rig.service.current(in: .all) else { break }
            shown.append(idea.title)
            let start = clock.now
            rig.service.another(in: .all)
            slowest = max(slowest, start.duration(to: clock.now))
            // Asked for in the same instant: nothing between the tap and the next card.
            #expect(rig.service.current(in: .all) != nil)
            #expect(!rig.service.isWaiting(in: .all))
        }
        #expect(Set(shown).count == 6, "six different cards")
        #expect(rig.writer.suggestionRequests.count == asked, "no request was made for a card: \(rig.writer.suggestionRequests.count - asked)")
        #expect(slowest < .milliseconds(50), "a tap took \(slowest)")
        print(String(format: "ROULETTE slowest tap: %.2f ms", Double(slowest.components.attoseconds) / 1e15))
    }

    @Test func theCardStaysWhenNewIdeasArriveUnderIt() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.holdsSuggestions = true
        rig.writer.suggestionBatches = [batch("Saving")]
        rig.service.prepare(for: .all)
        let starter = rig.service.current(in: .all)
        #expect(starter?.angle == nil && starter?.brief != nil, "a starter while the first ideas are written")
        rig.writer.holdsSuggestions = false
        while rig.writer.suggestionRequests.isEmpty || rig.service.isRefilling { await Task.yield() }
        await settle(rig)
        #expect(rig.service.current(in: .all) == starter, "only Another idea changes the card")
        rig.service.another(in: .all)
        #expect(rig.service.current(in: .all)?.angle != nil, "then the model's")
    }

    // MARK: - Refills

    @Test func aTopicsNextIdeasAreAskedForBeforeItRunsOutAndAboutItAlone() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving", count: 12), batch("Trip", niche: .travel)]
        await rig.service.refill()
        // Every idea so far is about finance: travel has nothing ahead.
        rig.service.prepare(for: .topic(travel))
        #expect(rig.service.current(in: .topic(travel))?.niche == .travel, "a travel starter at once")
        while rig.writer.suggestionRequests.count < 2 { await Task.yield() }
        let slots = rig.writer.suggestionRequests[1].slots
        #expect(slots.count == 6 && slots.allSatisfy { $0.topic.niche == .travel }, "the batch is about the topic shown")
        #expect(rig.writer.suggestionPriorities[1] == .prefetch, "a starter is on screen: nobody is waiting")
        await settle(rig)
        rig.service.another(in: .topic(travel))
        #expect(rig.service.current(in: .topic(travel))?.title.hasPrefix("Trip") == true)
    }

    @Test func browsingDownToTheLowWaterAsksForTheNextSixOnce() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        let routine = rig.profile.profile.ideaTopics[0]
        rig.writer.suggestionBatches = [batch("Routine", count: 9, topic: "Daily Routine"), batch("More", topic: "Daily Routine")]
        await rig.service.refill()
        rig.service.prepare(for: .topic(routine))
        // Eight ahead of the card's own: four taps leave four, the fifth leaves three, below the low water.
        for _ in 0..<4 { rig.service.another(in: .topic(routine)) }
        #expect(rig.writer.suggestionRequests.count == 1)
        rig.service.another(in: .topic(routine))
        rig.service.another(in: .topic(routine))
        while rig.writer.suggestionRequests.count < 2 || rig.service.isRefilling { await Task.yield() }
        await settle(rig)
        #expect(rig.writer.suggestionRequests.count == 2, "one refill for many taps")
    }

    @Test func otherTopicsCancelTheRefillForTheOldOnes() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.holdsSuggestions = true
        rig.writer.suggestionBatches = [batch("Old", topic: "Daily Routine"), batch("Garden", topic: "Gardening")]
        rig.service.prepare(for: .all)
        while rig.writer.suggestionRequests.isEmpty { await Task.yield() }
        var profile = rig.profile.profile
        profile.customTopics = ["Gardening"]
        rig.profile.profile = profile
        rig.service.prepare(for: .all)
        while rig.writer.cancelledSuggestions == 0 { await Task.yield() }
        rig.writer.holdsSuggestions = false
        await settle(rig)
        #expect(!rig.service.pool.contains { $0.title.hasPrefix("Old") }, "ideas for the old topics never land")
        #expect(rig.service.current(in: .all)?.topic == "Gardening")
    }

    // MARK: - Scripts first

    @Test func noRefillStartsWhileAScriptIsBeingWritten() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving")]
        rig.writer.beginScript()
        rig.service.prepare(for: .all)
        for _ in 0..<50 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(30))
        #expect(rig.writer.suggestionRequests.isEmpty, "nothing competes with the script")
        #expect(rig.service.current(in: .all) != nil, "a starter is shown meanwhile")
        rig.writer.endScript()
        while rig.writer.suggestionRequests.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(rig.writer.suggestionPriorities.first == .prefetch)
    }

    @Test func aScriptBegunMidRefillCancelsItAndTheIdeasAreAskedAgainAfter() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.holdsSuggestions = true
        rig.writer.suggestionBatches = [batch("Saving")]
        rig.service.prepare(for: .all)
        while rig.writer.suggestionRequests.isEmpty { await Task.yield() }
        rig.writer.beginScript()
        while rig.writer.cancelledSuggestions == 0 { await Task.yield() }
        #expect(rig.service.pool.isEmpty)
        #expect(!rig.service.refillFailed(in: .all), "a cancellation is not a failure")
        rig.writer.holdsSuggestions = false
        rig.writer.endScript()
        while rig.service.pool.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(rig.writer.suggestionRequests.count == 2)
    }

    // MARK: - Waiting and failing

    @Test func atTheEndTheCardWaitsForTheNextAndAFailureSaysSo() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        let routine = IdeaTopicFilter.topic(rig.profile.profile.ideaTopics[0])
        rig.writer.error = ScriptAIError.rateLimited
        rig.service.prepare(for: routine)
        // Without the model's ideas, the starters made from the topic's name, each once.
        var starters: Set<String> = []
        for _ in 0..<20 {
            guard let idea = rig.service.current(in: routine), !rig.service.isWaiting(in: routine) else { break }
            starters.insert(idea.id)
            rig.service.another(in: routine)
            await settle(rig)
        }
        #expect(starters.count == ThemeCatalog.ideas(for: rig.profile.profile.ideaTopics[0]).count)
        await settle(rig)
        #expect(rig.service.refillFailed(in: routine))
        #expect(!rig.service.isWaiting(in: routine))
        #expect(rig.service.current(in: routine) != nil, "the last card stays")
        rig.writer.error = nil
        rig.writer.suggestionBatches = [batch("Routine", topic: "Daily Routine")]
        rig.service.retry(in: routine)
        #expect(!rig.service.refillFailed(in: routine))
        while rig.service.isWaiting(in: routine) { await Task.yield() }
        #expect(rig.service.current(in: routine)?.title.hasPrefix("Routine") == true, "the idea waited for is on the card")
    }

    @Test func withoutAppleIntelligenceTheStartersGoRoundAndNothingWaits() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.isAvailable = false
        rig.service.prepare(for: .topic(finance))
        var seen: [String] = []
        for _ in 0..<8 {
            guard let idea = rig.service.current(in: .topic(finance)) else { break }
            seen.append(idea.title)
            rig.service.another(in: .topic(finance))
        }
        #expect(seen.count == 8 && Set(seen).count == 6, "six starters, then again")
        #expect(!rig.service.isWaiting(in: .topic(finance)))
        #expect(rig.writer.suggestionRequests.isEmpty)
    }

    // MARK: - One pool, one taste

    @Test func anIdeaPassedInTheRouletteIsNotShownOnTheCard() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving", count: 12)]
        await rig.service.refill()
        rig.service.prepare(for: .all)
        let card = rig.service.current
        let passed = rig.service.current(in: .all)
        #expect(passed != card, "the card keeps its own")
        rig.service.another(in: .all)
        for _ in 0..<10 {
            #expect(rig.service.current != passed)
            rig.service.another()
        }
    }

    @Test func passingPickingAndWritingTeachTheTasteInThatOrder() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving", count: 12)]
        await rig.service.refill()
        rig.service.prepare(for: .all)
        let passed = rig.service.current(in: .all)
        rig.service.another(in: .all)
        guard let picked = rig.service.current(in: .all), let pickedBrief = picked.brief else {
            Issue.record("Nothing to pick")
            return
        }
        rig.service.selected(picked)
        let pickedAngle = picked.angle ?? ""
        let passedAngle = passed?.angle ?? ""
        #expect(rig.service.taste.angles[passedAngle, default: 0] < 0)
        #expect(rig.service.taste.angles[pickedAngle, default: 0] == IdeaTaste.selectWeight)
        #expect(!rig.service.pool.contains(picked), "a picked idea leaves the roulette and the card")
        rig.service.generated(from: pickedBrief)
        #expect(rig.service.taste.angles[pickedAngle, default: 0] == IdeaTaste.selectWeight + IdeaTaste.generateWeight)
        #expect(IdeaTaste.passWeight < IdeaTaste.selectWeight && IdeaTaste.selectWeight < IdeaTaste.sendWeight)
        #expect(IdeaTaste.sendWeight < IdeaTaste.generateWeight)
    }

    @Test func aScriptFromAnIdeaStillInThePoolTakesItOut() async {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving", count: 12)]
        await rig.service.refill()
        rig.service.prepare(for: .all)
        let shown = rig.service.current(in: .all)!
        rig.service.generated(from: shown.brief!)
        #expect(!rig.service.pool.contains(shown))
        rig.service.prepare(for: .all)
        #expect(rig.service.current(in: .all) != shown)
    }

    // MARK: - Memory

    @Test func ideasSavedBeforeBriefsStillOpenAndAreReplacedForTheRoulette() async throws {
        let rig = rig { $0.niches = [.finance] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Saving")]
        await rig.service.refill()
        // What an older version saved: the same ideas without their briefs.
        let saved = try #require(rig.defaults.defaults.data(forKey: DefaultsKey.ideaSuggestions))
        var json = try #require(try JSONSerialization.jsonObject(with: saved) as? [String: Any])
        let pool = try #require(json["pool"] as? [[String: Any]])
        json["pool"] = pool.map { idea in idea.filter { $0.key != "brief" } }
        rig.defaults.defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: DefaultsKey.ideaSuggestions)
        rig.writer.isAvailable = false
        let reopened = IdeaSuggestionService(writer: rig.writer, profile: rig.profile, interfaceLanguage: { .english }, defaults: rig.defaults.defaults)
        #expect(reopened.current?.title.hasPrefix("Saving") == true, "the card keeps what it had")
        #expect(reopened.current?.brief == nil)
        #expect(reopened.current(in: .all)?.brief != nil, "the roulette shows only whole briefs")
    }
}
