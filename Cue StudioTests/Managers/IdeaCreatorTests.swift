//
//  IdeaCreatorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Who the ideas are for (`IdeaCreator`): the kind of creator and what their videos are for go with every request for ideas, the voice on or off,
/// and with the ingredients the ideas are made around (the owner, 03/11/2026: a lawyer who wants clients and to raise awareness).
@MainActor
@Suite("Who the ideas are for")
struct IdeaCreatorTests {
    private let lawyer = IdeaCreator(who: "a lawyer who explains people's rights in plain words", goals: [.winClients, .raiseAwareness])
    private let law = IdeaTopic(name: Niche.law.promptName, label: Niche.law.label, niche: .law)

    @Test func theLineSaysWhoTheyAreAndWhatTheVideosAreFor() {
        #expect(lawyer.promptLine == "The creator is a lawyer who explains people's rights in plain words. Their videos aim to win new clients "
            + "and raise awareness of a cause, and the ideas serve that.")
        #expect(IdeaCreator(who: nil, goals: [.teach]).promptLine == "Their videos aim to teach something useful, and the ideas serve that.")
        #expect(IdeaCreator(who: nil).promptLine == nil)
    }

    @Test func theProfileSaysItWhenTheCreatorDid() {
        #expect(CreatorProfile().ideaCreator == nil)
        let profile = CreatorProfile(role: .expert, contentGoals: [.winClients], creatorKind: "lawyer")
        #expect(profile.ideaCreator?.who == CreatorKind.find("lawyer")?.promptName && profile.ideaCreator?.goals == [.winClients])
        #expect(CreatorProfile(customRole: "Chess coach").ideaCreator?.who == "Chess coach")
    }

    @Test func theIdeasTheIngredientsAndTheEditAreAskedForThem() {
        let slots = [IdeaSlot(angle: .myth, topic: law)]
        let line = lawyer.promptLine ?? ""
        #expect(ScriptPromptBuilder.themesPrompt(slots: slots, asBriefs: true, creator: lawyer).contains(line))
        #expect(!ScriptPromptBuilder.themesPrompt(slots: slots, asBriefs: true).contains("The creator is"))
        let ingredients = ScriptPromptBuilder.ingredientsPrompt(.belief, topic: law, creator: lawyer, language: .portugueseBrazil)
        #expect(ingredients.contains("The creator is a lawyer") && ingredients.contains("and the subjects serve that"))
        let answers = [IdeaBriefReader.Answer(title: "Seus direitos", angle: "Explique.", openingLine: "Você sabia?")]
        #expect(ScriptPromptBuilder.ideaEditPrompt(answers: answers, slots: slots, language: .portugueseBrazil, creator: lawyer).contains(line))
    }

    @Test func aBatchForThemStillCostsLittleOfTheModelsWindow() {
        let topics = [law, IdeaTopic(name: Niche.finance.promptName, label: Niche.finance.label, niche: .finance)]
        let slots = IdeaTaste().slots(round: 0, among: topics)
        let prompt = ScriptPromptBuilder.themesPrompt(slots: slots, inspiration: ["Why Italian forms take three tries"], asBriefs: true, creator: lawyer)
        #expect(PromptCost.units(of: prompt + ScriptPromptBuilder.themesInstructions()) < 1_750)
    }

    @Test func theIngredientsOfATopicAreKeptForWhoTheyWereWrittenFor() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = IdeaIngredientStore(defaults: defaults.defaults)
        let found = IdeaIngredients(beliefs: ["Quem pede demissão perde tudo"], mistakes: [], moments: [], things: [])
        store.keep(found, for: law, in: .portugueseBrazil, creator: lawyer)
        #expect(store.due([law], in: .portugueseBrazil, for: lawyer).isEmpty)
        #expect(store.due([law], in: .portugueseBrazil) == [law], "for someone else, they are asked again")
        let seasoned = store.seasoned([IdeaSlot(angle: .myth, topic: law)], in: .portugueseBrazil, for: lawyer)
        #expect(seasoned.first?.subject == "Quem pede demissão perde tudo")
    }

    @Test func theServiceAsksForThemWithTheVoiceOff() async {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var created = profile.profile
        created.niches = [.law]
        created.role = .expert
        created.creatorKind = "lawyer"
        created.contentGoals = [.winClients]
        created.usesVoiceInAI = false
        profile.profile = created
        let writer = FakeScriptWriter()
        let service = IdeaSuggestionService(
            writer: writer, profile: profile, interfaceLanguage: { .english }, inspiration: { [] }, notes: { [] }, defaults: defaults.defaults
        )
        await service.refill()
        let asked = writer.suggestionCreators.first ?? nil
        #expect(asked?.who == CreatorKind.find("lawyer")?.promptName && asked?.goals == [.winClients])
        #expect(writer.ingredientCreators.first??.who == asked?.who)
    }
}
