//
//  IdeaIngredientTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The ingredients of the ideas (`IdeaIngredients`): asked of Private Cloud Compute once a week a topic, kept on the iPhone, one subject to each idea
/// in turn by the kind its angle takes, and nothing changes where they can't be written.
@MainActor
@Suite("Idea ingredients")
struct IdeaIngredientTests {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private let finance = IdeaTopic(name: Niche.finance.promptName, label: Niche.finance.label, niche: .finance)
    private let food = IdeaTopic(name: Niche.food.promptName, label: Niche.food.label, niche: .food)

    private static let sample = IdeaIngredients(
        beliefs: ["cartão de crédito é sempre ruim", "poupança rende bem"],
        mistakes: ["pagar só o mínimo da fatura", "parcelar o mercado"],
        moments: ["fila do banco na hora do almoço"],
        things: ["cofrinho de moedas", "planilha no caderno"]
    )

    // MARK: - What they are

    @Test func eachAngleTakesTheKindItSuits() {
        #expect(IdeaIngredientKind(angle: .myth) == .belief)
        #expect(IdeaIngredientKind(angle: .lesson) == .mistake)
        #expect(IdeaIngredientKind(angle: .story) == .moment)
        #expect(IdeaIngredientKind(angle: .comparison) == .thing)
        #expect(Set(IdeaAngle.allCases.map(IdeaIngredientKind.init(angle:))) == Set(IdeaIngredientKind.allCases), "every kind is used")
    }

    @Test func theModelsListsAreTrimmedAndNothingComesTwiceOrRunsOn() {
        let raw = IdeaIngredients(
            beliefs: [" pão engorda. ", "Pão engorda", ""],
            mistakes: [String(repeating: "palavra ", count: 12)],
            moments: ["café da manhã de pé"],
            things: ["pão engorda"]
        )
        let cleaned = raw.cleaned()
        #expect(cleaned.beliefs == ["pão engorda"])
        #expect(cleaned.mistakes.isEmpty)
        #expect(cleaned.things.isEmpty, "the same subject in another list is the same subject")
        #expect(cleaned.moments == ["café da manhã de pé"])
    }

    // MARK: - The store

    @Test func aTopicIsDueUntilItHasIngredientsAndAgainAWeekLater() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let clock = Clock()
        let store = IdeaIngredientStore(defaults: defaults.defaults, now: { clock.date })
        #expect(store.due([finance, food], in: .portugueseBrazil) == [finance, food])
        store.keep(Self.sample, for: finance, in: .portugueseBrazil)
        #expect(store.due([finance, food], in: .portugueseBrazil) == [food])
        #expect(store.due([finance], in: .spanish) == [finance], "each language has its own")
        clock.date += IdeaIngredientStore.freshFor
        #expect(store.due([finance], in: .portugueseBrazil) == [finance])
    }

    @Test func aTopicWithoutAnAnswerWaitsAnHourBeforeItIsAskedAgain() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let clock = Clock()
        let store = IdeaIngredientStore(defaults: defaults.defaults, now: { clock.date })
        store.noteFailure(for: finance, in: .portugueseBrazil)
        #expect(store.due([finance], in: .portugueseBrazil).isEmpty)
        clock.date += IdeaIngredientStore.retryAfter
        #expect(store.due([finance], in: .portugueseBrazil) == [finance])
        store.keep(IdeaIngredients(), for: finance, in: .portugueseBrazil)
        #expect(store.due([finance], in: .portugueseBrazil).isEmpty, "nothing usable counts as no answer")
    }

    @Test func eachSlotGetsTheNextSubjectOfItsKindAndATiedSlotKeepsItsTie() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = IdeaIngredientStore(defaults: defaults.defaults)
        store.keep(Self.sample, for: finance, in: .portugueseBrazil)
        var tied = IdeaSlot(angle: .story, topic: finance)
        tied.tie = .followUp("Como saí do rotativo")
        let slots = [IdeaSlot(angle: .myth, topic: finance), IdeaSlot(angle: .fact, topic: finance), tied, IdeaSlot(angle: .list, topic: food)]
        let seasoned = store.seasoned(slots, in: .portugueseBrazil)
        #expect(seasoned[0].subject == "cartão de crédito é sempre ruim")
        #expect(seasoned[1].subject == "poupança rende bem", "the next one of the kind")
        #expect(seasoned[2].subject == nil)
        #expect(seasoned[3].subject == nil, "a topic without ingredients goes as it was")
        let again = store.seasoned([IdeaSlot(angle: .myth, topic: finance)], in: .portugueseBrazil)
        #expect(again[0].subject == "cartão de crédito é sempre ruim", "after the last, the first again")
    }

    @Test func theIngredientsAndTheirTurnsAreThereWhenTheAppOpensAgain() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let first = IdeaIngredientStore(defaults: defaults.defaults)
        first.keep(Self.sample, for: finance, in: .portugueseBrazil)
        _ = first.seasoned([IdeaSlot(angle: .mistake, topic: finance)], in: .portugueseBrazil)
        let reopened = IdeaIngredientStore(defaults: defaults.defaults)
        #expect(reopened.due([finance], in: .portugueseBrazil).isEmpty)
        #expect(reopened.seasoned([IdeaSlot(angle: .mistake, topic: finance)], in: .portugueseBrazil)[0].subject == "parcelar o mercado")
    }

    // MARK: - The prompts

    @Test func aSlotWithASubjectAsksForTheIdeaAroundIt() {
        var slot = IdeaSlot(angle: .mistake, topic: finance)
        slot.subject = "pagar só o mínimo da fatura"
        let prompt = ScriptPromptBuilder.themesPrompt(slots: [slot], language: .portugueseBrazil, asBriefs: true)
        #expect(prompt.contains("a common mistake and how to fix it about \(Niche.finance.promptName), around this subject: pagar só o mínimo da fatura"))
    }

    @Test func theIngredientsOfATopicStayClearOfTheCreatorsOtherTopics() {
        let prompt = ScriptPromptBuilder.ingredientsPrompt(.moment, topic: finance, others: [food], language: .portugueseBrazil)
        #expect(prompt.contains("Keep to \(Niche.finance.promptName) itself: nothing that belongs more to \(Niche.food.promptName)."))
        #expect(!ScriptPromptBuilder.ingredientsPrompt(.moment, topic: finance, language: .portugueseBrazil).contains("Keep to"))
    }

    @Test func twoIdeasOfABatchJoinTwoTopicsTheAnglesTheyMeetInFirstAndNeverWithOneTopicAlone() {
        let mine = [finance, food]
        let slots = [IdeaSlot(angle: .myth, topic: finance), IdeaSlot(angle: .list, topic: food), IdeaSlot(angle: .story, topic: finance)]
        let bridged = IdeaSlot.bridging(slots, among: mine, round: 0)
        #expect(bridged.map { $0.bridge } == [nil, finance, food], "a list and a story before a myth, each with its other topic")
        #expect(IdeaSlot.bridging(slots, among: [finance], round: 1).allSatisfy { $0.bridge == nil })
        var tied = slots
        tied[1].tie = .followUp("Como saí do rotativo")
        #expect(IdeaSlot.bridging(tied, among: mine, round: 0)[1].bridge == nil, "a tied idea is about what it is tied to")
        let three = [finance, food, IdeaTopic.lifestyle]
        var joins: [Set<IdeaTopic>] = []
        for round in 0..<3 {
            let batch = IdeaSlot.bridging(IdeaTaste().slots(round: round, among: three), among: three, round: round)
            let pairs = batch.compactMap { slot in slot.bridge.map { Set([slot.topic, $0]) } }
            #expect(pairs.count == 2 && pairs[0] != pairs[1], "two different pairs in a batch")
            joins += pairs
        }
        #expect(three.allSatisfy { topic in joins.filter { $0.contains(topic) }.count == 4 }, "every pair in turn: \(joins)")
        var joined = IdeaSlot(angle: .comparison, topic: food)
        joined.bridge = finance
        #expect(ScriptPromptBuilder.themesPrompt(slots: [joined], asBriefs: true)
            .contains("about \(Niche.food.promptName), joined with \(Niche.finance.promptName): one idea where the two meet"))
    }

    @Test func oneIdeaOfABatchIsLeftOpenAndJoinedOrOpenIdeasGetNoSubject() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = IdeaIngredientStore(defaults: defaults.defaults)
        store.keep(Self.sample, for: finance, in: .portugueseBrazil)
        var slots = [IdeaSlot(angle: .myth, topic: finance), IdeaSlot(angle: .mistake, topic: finance), IdeaSlot(angle: .list, topic: finance)]
        slots[2].bridge = food
        let opened = IdeaSlot.opening(slots, round: 1)
        #expect(opened.map(\.isOpen) == [false, true, false], "neither the joined one nor the same angle every batch")
        let seasoned = store.seasoned(opened, in: .portugueseBrazil)
        #expect(seasoned.map { $0.subject != nil } == [true, false, false])
    }

    @Test func ideasWithoutASubjectGoThroughTheSubtopicsTheCreatorChoseInTurn() {
        var cooking = food
        cooking.subtopics = ["Home cooking", "Fine dining", "Street food"]
        var slots = [IdeaSlot(angle: .myth, topic: cooking), IdeaSlot(angle: .list, topic: cooking), IdeaSlot(angle: .story, topic: cooking)]
        slots[0].subject = "Lavar o arroz"
        slots[2].bridge = finance
        let first = IdeaSlot.focusing(slots, round: 0)
        #expect(first.map(\.subtopic) == [nil, "Home cooking", nil], "a subject or another topic says what it is about")
        let next = IdeaSlot.focusing(slots, round: 1)
        #expect(next[1].subtopic == "Fine dining", "the next batch, the next subtopic")
        #expect(IdeaSlot.focusing(slots, round: 3)[1].subtopic == "Home cooking", "round and round")
        let two = IdeaSlot.focusing([IdeaSlot(angle: .list, topic: cooking), IdeaSlot(angle: .tool, topic: cooking)], round: 1)
        #expect(two.map(\.subtopic) == ["Street food", "Home cooking"], "two of a topic in a batch, each the next")
        #expect(IdeaSlot.focusing([IdeaSlot(angle: .list, topic: finance)], round: 0)[0].subtopic == nil, "a topic without subtopics, as it was")
        #expect(ScriptPromptBuilder.themesPrompt(slots: first, asBriefs: true).contains("about \(cooking.name) (Home cooking)"))
    }

    @Test func theIngredientsAreAskedInTheLanguageForItsCountry() {
        let instructions = ScriptPromptBuilder.ingredientsInstructions(language: .portugueseBrazil)
        let prompt = ScriptPromptBuilder.ingredientsPrompt(.mistake, topic: finance, language: .portugueseBrazil)
        #expect(instructions.hasPrefix("The person's locale is pt_BR."))
        #expect(instructions.contains("You MUST respond in Portuguese"))
        #expect(prompt.hasPrefix("List 8 mistakes people in Brazil commonly make with \(Niche.finance.promptName)"))
        #expect(prompt.contains("Write them in Portuguese"))
    }

    // MARK: - The editor

    private static func answer(_ title: String) -> IdeaBriefReader.Answer {
        IdeaBriefReader.Answer(title: title, angle: "Mostre como \(title.lowercased()).", openingLine: "Hoje: \(title.lowercased()).")
    }

    private var three: [IdeaSlot] {
        [IdeaSlot(angle: .myth, topic: finance), IdeaSlot(angle: .story, topic: finance), IdeaSlot(angle: .list, topic: food)]
    }

    @Test func theEditorsWordsTakeThePlaceOfTheDraftsAndWhatItDropsGoesWithItsSlot() {
        let drafts = ["Mito sobre finanças", "Comida engorda de viagem", "Lista de pratos"].map(Self.answer)
        let edits: [IdeaBriefReader.Answer?] = [Self.answer("O cartão de crédito não é o vilão"), nil, Self.answer("")]
        let (answers, slots) = IdeaBriefReader.edited(drafts, slots: three, by: edits)
        #expect(answers.map(\.title) == ["O cartão de crédito não é o vilão", "Lista de pratos"], "an empty edit keeps the draft")
        #expect(slots.map(\.angle) == [.myth, .list])
    }

    @Test func anEditThatDropsEverythingOrAnswersForFewerIdeasIsNotTrustedForTheRest() {
        let drafts = ["Um", "Dois", "Três"].map(Self.answer)
        let none = IdeaBriefReader.edited(drafts, slots: three, by: [nil, nil, nil])
        #expect(none.answers.map(\.title) == ["Um", "Dois", "Três"])
        let short = IdeaBriefReader.edited(drafts, slots: three, by: [Self.answer("Primeiro")])
        #expect(short.answers.map(\.title) == ["Primeiro", "Dois", "Três"])
    }

    @Test func theEditorReadsEachIdeaWithWhatItWasAskedFor() {
        var slot = IdeaSlot(angle: .mistake, topic: finance)
        slot.subject = "pagar só o mínimo da fatura"
        let prompt = ScriptPromptBuilder.ideaEditPrompt(answers: [Self.answer("Erro de fatura")], slots: [slot], language: .portugueseBrazil)
        #expect(prompt.contains("as a creator from Brazil would post and say them"))
        #expect(prompt.contains("1. Kind: a common mistake and how to fix it. Topic: \(Niche.finance.promptName). Subject: pagar só o mínimo da fatura. "
            + "Title: Erro de fatura"))
        #expect(ScriptPromptBuilder.ideaEditInstructions(language: .portugueseBrazil).hasPrefix("The person's locale is pt_BR."))
    }

    // MARK: - The ideas

    private func service(writer: FakeScriptWriter, defaults: TestDefaults, clock: Clock) -> IdeaSuggestionService {
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var created = profile.profile
        created.niches = [.finance]
        profile.profile = created
        return IdeaSuggestionService(
            writer: writer, profile: profile, interfaceLanguage: { .portugueseBrazil }, now: { clock.date }, defaults: defaults.defaults
        )
    }

    @Test func theIdeasAreAskedAroundTheSubjectsAndTheIngredientsOnlyOnceAWeek() async {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let clock = Clock()
        let writer = FakeScriptWriter()
        writer.ingredients = Self.sample
        let service = service(writer: writer, defaults: defaults, clock: clock)
        await service.refill()
        #expect(writer.ingredientRequests.map(\.topic) == [Niche.finance.promptName])
        #expect(writer.ingredientRequests.first?.language == .portugueseBrazil)
        #expect(writer.ingredientRequests.first?.others.isEmpty == true, "one topic: nothing to keep clear of")
        let slots = writer.suggestionRequests.first?.slots ?? []
        #expect(slots.filter { $0.subject != nil }.count == slots.count - IdeaSlot.openPerBatch, "one is left open, one topic joins none")
        await service.refill()
        #expect(writer.ingredientRequests.count == 1, "kept for the week")
    }

    @Test func withoutPrivateCloudComputeTheIdeasAreAskedAsBeforeAndTheTopicIsNotAskedAgainAtOnce() async {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let clock = Clock()
        let writer = FakeScriptWriter()
        let service = service(writer: writer, defaults: defaults, clock: clock)
        await service.refill()
        #expect(writer.ingredientRequests.count == 1)
        #expect(writer.suggestionRequests.first?.slots.allSatisfy { $0.subject == nil } == true)
        await service.refill()
        #expect(writer.ingredientRequests.count == 1, "an hour before it is asked again")
    }
}
