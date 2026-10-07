//
//  IdeaSuggestionServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The card's suggested idea and "↻ another idea": the model's ideas about all the creator's topics, none repeated, the starters until they arrive.
@MainActor
@Suite("Idea suggestions")
struct IdeaSuggestionServiceTests {
    private struct Rig {
        let service: IdeaSuggestionService
        let writer: FakeScriptWriter
        let profile: CreatorProfileService
        let defaults: TestDefaults
    }

    private func rig(profile edit: (inout CreatorProfile) -> Void = { _ in }) -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var created = profile.profile
        edit(&created)
        profile.profile = created
        let writer = FakeScriptWriter()
        let service = IdeaSuggestionService(writer: writer, profile: profile, interfaceLanguage: { .english }, defaults: defaults.defaults)
        return Rig(service: service, writer: writer, profile: profile, defaults: defaults)
    }

    private func batch(_ prefix: String, count: Int = 6, niche: Niche = .lifestyle) -> [ThemeIdea] {
        (1...count).map { ThemeIdea(title: "\(prefix) \($0)", kind: "List", length: .minute1, niche: niche) }
    }

    // MARK: - Starters

    @Test func withNoTopicsTheStartersAreLifestyleAndAnotherOneRotates() {
        let rig = rig()
        defer { rig.defaults.tearDown() }
        let first = rig.service.current
        rig.service.another()
        let second = rig.service.current
        #expect(first?.niche == .lifestyle && second?.niche == .lifestyle)
        #expect(first != second)
    }

    @Test func aFirstFlightTopicHasItsOwnStarters() {
        let rig = rig { $0.niches = [.finance] }
        defer { rig.defaults.tearDown() }
        #expect(rig.service.current?.niche == .finance)
    }

    @Test func aCreatorWhoHoldsOnlyTheirOwnTopicsGetsNoStarterAboutSomethingElse() {
        let rig = rig { $0.customTopics = ["Daily Routine"]; $0.voiceTopics = [.languages] }
        defer { rig.defaults.tearDown() }
        #expect(rig.service.current == nil)
    }

    // MARK: - The model's ideas

    @Test func theModelsIdeasTakeTheCardsPlaceAndAnotherWalksThroughThem() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("First")]
        await rig.service.refill()
        #expect(rig.service.current?.title == "First 1")
        rig.service.another()
        #expect(rig.service.current?.title == "First 2")
        rig.service.another()
        rig.service.another()
        #expect(rig.service.current?.title == "First 4")
    }

    @Test func theRequestCarriesEveryTopicWithItsSubtopics() async {
        let rig = rig {
            $0.niches = [.finance]
            $0.customTopics = ["Daily Routine"]
            $0.topicDetails = ["Daily Routine": ["Bureaucracy"]]
        }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("A")]
        await rig.service.refill()
        let topics = rig.writer.suggestionRequests.first?.topics
        #expect(topics?.count == 2 && topics?.last?.name == "Daily Routine")
        #expect(topics?.last?.subtopics == ["Bureaucracy"])
        #expect(topics?.first?.niche == .finance && topics?.last?.niche == nil)
    }

    @Test func aNewBatchIsAskedForWhenFewAreLeftAndTheModelIsToldWhatCameBefore() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("First"), batch("Second")]
        await rig.service.refill()
        for _ in 0..<4 { rig.service.another() }
        // Two are left of six: the next six are on their way; wait for them.
        while rig.writer.suggestionRequests.count < 2 { await Task.yield() }
        while rig.service.isRefilling { await Task.yield() }
        #expect(rig.writer.suggestionRequests.last?.avoiding == (1...6).map { "First \($0)" })
        #expect(rig.writer.suggestionRequests.map(\.round) == [0, 1], "each batch looks at the topics from other angles")
        #expect(rig.service.pool.count == 12)
    }

    @Test func anIdeaThatCameBeforeIsNotAddedAgain() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Same", count: 3), batch("Same", count: 3) + batch("New", count: 2)]
        await rig.service.refill()
        await rig.service.refill()
        #expect(rig.service.pool.map(\.title) == ["Same 1", "Same 2", "Same 3", "New 1", "New 2"])
    }

    @Test func anIdeaRewordedIsTheSameIdea() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        let first = [ThemeIdea(title: "Morning Check-Ins: Daily Routine", kind: "List", length: .minute1, niche: .lifestyle)]
        let reworded = [ThemeIdea(title: "Daily Routine Morning Check-Ins", kind: "List", length: .minute1, niche: .lifestyle)]
        rig.writer.suggestionBatches = [first, reworded + batch("Other", count: 4)]
        await rig.service.refill()
        await rig.service.refill()
        #expect(rig.service.pool.map(\.title).filter { $0.contains("Check-Ins") }.count == 1)
        #expect(rig.service.pool.count >= 5)
    }

    @Test func aFailureLeavesTheStartersWhereTheyWere() async {
        let rig = rig { $0.niches = [.travel] }
        defer { rig.defaults.tearDown() }
        let before = rig.service.current
        rig.writer.error = ScriptAIError.rateLimited
        await rig.service.refill()
        #expect(rig.service.current == before && rig.service.pool.isEmpty)
    }

    @Test func withoutTheModelNothingIsAsked() {
        let rig = rig { $0.niches = [.travel] }
        defer { rig.defaults.tearDown() }
        rig.writer.isAvailable = false
        rig.service.prepare()
        rig.service.another()
        #expect(rig.writer.suggestionRequests.isEmpty)
        #expect(rig.service.current?.niche == .travel)
    }

    // MARK: - Topics changed, and memory

    @Test func otherTopicsMakeTheIdeasWrittenForTheOldOnesGo() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Old")]
        await rig.service.refill()
        #expect(rig.service.current?.title == "Old 1")
        var profile = rig.profile.profile
        profile.customTopics = ["Gardening"]
        rig.profile.profile = profile
        rig.service.prepare()
        #expect(rig.service.pool.isEmpty)
        #expect(rig.service.current == nil)
    }

    @Test func theIdeasNotYetShownAreThereWhenTheAppOpensAgain() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Kept")]
        await rig.service.refill()
        rig.service.another()
        let reopened = IdeaSuggestionService(writer: rig.writer, profile: rig.profile, interfaceLanguage: { .english }, defaults: rig.defaults.defaults)
        #expect(reopened.current?.title == "Kept 2")
        let otherLanguage = IdeaSuggestionService(
            writer: rig.writer, profile: rig.profile, interfaceLanguage: { .portugueseBrazil }, defaults: rig.defaults.defaults
        )
        #expect(otherLanguage.pool.isEmpty, "ideas written in one language are not shown in another")
    }

    @Test func anIdeaForOneOfTheCreatorsOwnTopicsSaysWhichInItsLabel() {
        let idea = ThemeIdea(title: "T", kind: "List", length: .minute1, niche: .lifestyle, topic: "Daily Routine")
        #expect(idea.meta == "List · ~1 min · Daily Routine")
        let starter = ThemeIdea(title: "T", kind: "List", length: .minute1, niche: .finance)
        #expect(starter.meta == "List · ~1 min · \(Niche.finance.label)")
    }
}
