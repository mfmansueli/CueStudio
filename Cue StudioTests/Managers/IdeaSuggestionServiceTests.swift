//
//  IdeaSuggestionServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The card's suggested idea and "↻ another idea": the model's ideas about all the creator's topics, in the direction of what they wrote, none repeated,
/// leaning to what they send, and the starters until they arrive.
@MainActor
@Suite("Idea suggestions")
struct IdeaSuggestionServiceTests {
    private final class Notes {
        var inspiration: [String] = []
        var entries: [LogbookEntry] = []
    }

    private struct Rig {
        let service: IdeaSuggestionService
        let writer: FakeScriptWriter
        let profile: CreatorProfileService
        let defaults: TestDefaults
        let notes: Notes
    }

    private func rig(profile edit: (inout CreatorProfile) -> Void = { _ in }) -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var created = profile.profile
        edit(&created)
        profile.profile = created
        let writer = FakeScriptWriter()
        let notes = Notes()
        let service = IdeaSuggestionService(
            writer: writer, profile: profile, interfaceLanguage: { .english }, inspiration: { notes.inspiration }, notes: { notes.entries },
            defaults: defaults.defaults
        )
        return Rig(service: service, writer: writer, profile: profile, defaults: defaults, notes: notes)
    }

    private func batch(_ prefix: String, count: Int = 6, niche: Niche = .lifestyle, angle: IdeaAngle? = .list) -> [ThemeIdea] {
        (1...count).map { number in
            var idea = ThemeIdea(title: "\(prefix) \(number)", kind: "List", length: .minute1, niche: niche)
            idea.angle = angle?.rawValue
            return idea
        }
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

    @Test func theRequestAsksForAnIdeaForEachSlotAboutAllTheTopicsAndEachBatchLooksFromOtherAngles() async {
        let rig = rig {
            $0.niches = [.finance]
            $0.customTopics = ["Daily Routine"]
            $0.topicDetails = ["Daily Routine": ["Bureaucracy"]]
        }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("A", count: 1), batch("B", count: 6)]
        await rig.service.refill()
        let first = rig.writer.suggestionRequests.first?.slots ?? []
        #expect(first.count == 6)
        #expect(Set(first.map(\.topic.name)).count == 2, "both topics have slots")
        #expect(first.first { $0.topic.name == "Daily Routine" }?.topic.subtopics == ["Bureaucracy"])
        #expect(first.first { $0.topic.niche != nil }?.topic.niche == .finance)
        let second = rig.writer.suggestionRequests.dropFirst().first?.slots ?? []
        #expect(!second.isEmpty && Set(first.map(\.angle)).isDisjoint(with: Set(second.map(\.angle))))
    }

    @Test func aNewBatchIsAskedForBeforeTheCreatorReachesTheEnd() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("First"), batch("Second")]
        await rig.service.refill()
        // Six ideas, one shown: five ahead is enough. Two taps and four are left: the next six are on their way.
        rig.service.another()
        #expect(rig.writer.suggestionRequests.count == 1)
        rig.service.another()
        while rig.writer.suggestionRequests.count < 2 { await Task.yield() }
        while rig.service.isRefilling { await Task.yield() }
        #expect(rig.service.pool.count == 12)
    }

    @Test func whatTheCreatorWroteLatelyGoesWithTheRequest() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.notes.inspiration = ["Why Italian forms take three tries"]
        rig.writer.suggestionBatches = [batch("A")]
        await rig.service.refill()
        #expect(rig.writer.suggestionRequests.first?.inspiration == ["Why Italian forms take three tries"])
    }

    @Test func anIdeaThatCameBeforeOrIsTheSameInOtherWordsIsNotAddedAgain() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        let reworded = [ThemeIdea(title: "Daily Routine Morning Check-Ins", kind: "List", length: .minute1, niche: .lifestyle)]
        let first = [ThemeIdea(title: "Morning Check-Ins: Daily Routine", kind: "List", length: .minute1, niche: .lifestyle)]
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

    // MARK: - What the creator passes and sends

    @Test func anIdeaPassedCostsItsAngleAndTheOneSentIsWorthMore() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        var items = batch("Idea", angle: .myth)
        items[2].angle = IdeaAngle.story.rawValue
        rig.writer.suggestionBatches = [items]
        await rig.service.refill()
        rig.service.another()
        rig.service.another()
        #expect(rig.service.taste.angles[IdeaAngle.myth.rawValue, default: 0] < 0, "two myths passed")
        #expect(rig.service.current?.angle == IdeaAngle.story.rawValue)
        #expect(rig.service.sent() == nil)
        #expect(rig.service.taste.angles[IdeaAngle.story.rawValue, default: 0] > 0, "the story was the one sent")
    }

    @Test func theNextBatchLeansToWhatWasSent() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("A", angle: .prediction), batch("B")]
        await rig.service.refill()
        rig.service.sent()
        rig.service.sent()
        await rig.service.refill()
        let asked = rig.writer.suggestionRequests.last?.slots.map(\.angle) ?? []
        #expect(asked.contains(.prediction), "the angle they sent is asked for again")
        #expect(Set(asked).count == asked.count)
    }

    // MARK: - Their own notes

    @Test func aNoteOfTheirsComesUpAmongTheModelsIdeasAndSendingItReturnsIt() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        let note = LogbookEntry(text: "A video about why I stopped planning my week", createdAt: .now)
        rig.notes.entries = [note]
        rig.writer.suggestionBatches = [batch("First", count: 12)]
        await rig.service.refill()
        for _ in 0..<IdeaSuggestionService.logbookEvery { rig.service.another() }
        #expect(rig.service.current?.title == note.text, "after four of the model's, one of their own")
        #expect(rig.service.current?.logbookID == note.id)
        #expect(rig.service.sent() == note.id)
        #expect(rig.service.current?.logbookID == nil)
        for _ in 0..<(IdeaSuggestionService.logbookEvery + 1) { rig.service.another() }
        #expect(rig.service.current?.logbookID == nil, "a note is shown once")
    }

    // MARK: - The end of the ideas

    @Test func atTheEndOfTheIdeasTheCardWaitsForTheNextOnesInsteadOfGoingQuiet() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("First", count: 4), batch("Second")]
        await rig.service.refill()
        rig.service.prepare()
        for _ in 0..<3 { rig.service.another() }
        #expect(!rig.service.isWaiting && rig.service.current?.title == "First 4")
        rig.service.another()
        #expect(rig.service.isWaiting)
        #expect(rig.service.current?.title == "First 4", "the last one stays while the next come")
        while rig.service.isWaiting { await Task.yield() }
        #expect(rig.service.current?.title == "Second 1")
    }

    // MARK: - Topics changed, and memory

    @Test func otherTopicsMakeTheIdeasWrittenForTheOldOnesGoButTheTasteStays() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Old", angle: .myth)]
        await rig.service.refill()
        rig.service.sent()
        var profile = rig.profile.profile
        profile.customTopics = ["Gardening"]
        rig.profile.profile = profile
        rig.service.prepare()
        #expect(rig.service.pool.isEmpty)
        #expect(rig.service.current == nil)
        #expect(rig.service.taste.angles[IdeaAngle.myth.rawValue, default: 0] > 0)
    }

    @Test func theIdeasNotYetShownAndTheTasteAreThereWhenTheAppOpensAgain() async {
        let rig = rig { $0.customTopics = ["Daily Routine"] }
        defer { rig.defaults.tearDown() }
        rig.writer.suggestionBatches = [batch("Kept", angle: .story)]
        await rig.service.refill()
        rig.service.sent()
        let reopened = IdeaSuggestionService(writer: rig.writer, profile: rig.profile, interfaceLanguage: { .english }, defaults: rig.defaults.defaults)
        #expect(reopened.current?.title == "Kept 2")
        #expect(reopened.taste.angles[IdeaAngle.story.rawValue, default: 0] > 0)
        let otherLanguage = IdeaSuggestionService(
            writer: rig.writer, profile: rig.profile, interfaceLanguage: { .portugueseBrazil }, defaults: rig.defaults.defaults
        )
        #expect(otherLanguage.pool.isEmpty, "ideas written in one language are not shown in another")
        #expect(otherLanguage.taste.angles[IdeaAngle.story.rawValue, default: 0] > 0, "what they like is theirs in any language")
    }

    @Test func anIdeaForOneOfTheCreatorsOwnTopicsSaysWhichInItsLabel() {
        let idea = ThemeIdea(title: "T", kind: "List", length: .minute1, niche: .lifestyle, topic: "Daily Routine")
        #expect(idea.meta == "List · ~1 min · Daily Routine")
        let starter = ThemeIdea(title: "T", kind: "List", length: .minute1, niche: .finance)
        #expect(starter.meta == "List · ~1 min · \(Niche.finance.label)")
    }
}
