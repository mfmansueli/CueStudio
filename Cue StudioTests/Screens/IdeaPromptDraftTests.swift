//
//  IdeaPromptDraftTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The empty Scripts screen's card: a chip picks a question and never touches the text, and nothing is
/// sent from an empty field.
@MainActor
@Suite("Idea prompt card")
struct IdeaPromptDraftTests {
    @Test func nothingIsSentFromAnEmptyFieldOrOneWithOnlySpaces() {
        var draft = IdeaPromptDraft()
        #expect(!draft.canSubmit(isAvailable: true) && draft.seed == nil)
        draft.text = "  \n  "
        #expect(!draft.canSubmit(isAvailable: true) && draft.seed == nil)
        // A kind alone is not an idea either: the placeholder and the question are never content.
        draft.toggle(.tip)
        #expect(!draft.canSubmit(isAvailable: true) && draft.seed == nil)
    }

    @Test func theTextAndTheKindGoTogetherWithoutTheSpacesAroundThem() {
        var draft = IdeaPromptDraft()
        draft.text = "  Three ways to focus  "
        #expect(draft.canSubmit(isAvailable: true))
        #expect(draft.seed == ScriptIdeaSeed(text: "Three ways to focus", idea: nil))
        draft.toggle(.tip)
        #expect(draft.seed == ScriptIdeaSeed(text: "Three ways to focus", idea: .tip))
    }

    @Test func withoutAModelTheArrowStaysOffEvenWithText() {
        var draft = IdeaPromptDraft()
        draft.text = "Three ways to focus"
        #expect(!draft.canSubmit(isAvailable: false))
    }

    @Test func oneKindAtATimeAndTheSameOneAgainLetsGo() {
        var draft = IdeaPromptDraft()
        #expect(draft.toggle(.tip))
        #expect(draft.idea == .tip)
        #expect(draft.toggle(.story))
        #expect(draft.idea == .story)
        // Letting go goes back to a free idea and doesn't ask for the keyboard.
        #expect(!draft.toggle(.story))
        #expect(draft.idea == nil)
    }

    @Test func switchingKindsNeverChangesWhatWasTyped() {
        var draft = IdeaPromptDraft()
        draft.text = "My morning routine\nin three steps"
        for option in [ScriptIdea.tip, .product, .story, .story, .tip] {
            draft.toggle(option)
            #expect(draft.text == "My morning routine\nin three steps")
        }
    }

    @Test func eachKindAsksItsOwnQuestionInTheInterfaceLanguage() {
        #expect(ScriptIdea.allCases.map(\.rawValue) == ["tip", "product", "story"])
        #expect(ScriptIdea.tip.question == "What do you want to teach?")
        #expect(ScriptIdea.product.question == "Which product, and what do you like about it?")
        #expect(ScriptIdea.story.question == "What happened?")
        #expect(ScriptIdea.allCases.map(\.label) == ["Share a tip", "Show a product", "Tell a story"])
        #expect(Set(ScriptIdea.allCases.map(\.instruction)).count == 3)
    }

    @Test func theKindReachesTheModelWithTheText() async {
        let writer = FakeScriptWriter()
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let viewModel = GenerateScriptViewModel(
            seed: ScriptIdeaSeed(text: "Why I quit coffee", idea: .story), writer: writer,
            library: ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now }),
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(), toast: ToastService()
        )
        #expect(viewModel.promptText == "Why I quit coffee" && viewModel.idea == .story)
        let script = await viewModel.generateFromPrompt()
        #expect(script != nil)
        #expect(writer.lastRequest?.idea == .story)
        #expect(writer.lastRequest?.source == .prompt("Why I quit coffee"))
        let prompt = ScriptPromptBuilder.prompt(for: writer.lastRequest!)
        #expect(prompt.contains("The video: Why I quit coffee"))
        #expect(prompt.contains(ScriptIdea.story.instruction))
    }

    @Test func aFreeIdeaSendsNoKindAndTheSheetStaysEmptyWithoutASeed() async {
        let writer = FakeScriptWriter()
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let viewModel = GenerateScriptViewModel(
            writer: writer, library: ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now }),
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(), toast: ToastService()
        )
        #expect(viewModel.promptText.isEmpty && viewModel.idea == nil)
        // Nothing is written from an empty prompt.
        #expect(await viewModel.generateFromPrompt() == nil)
        #expect(writer.lastRequest == nil)
        viewModel.promptText = "A day in my life"
        _ = await viewModel.generateFromPrompt()
        #expect(writer.lastRequest?.idea == nil)
        let prompt = ScriptPromptBuilder.prompt(for: writer.lastRequest!)
        #expect(!prompt.contains(ScriptIdea.tip.instruction) && !prompt.contains(ScriptIdea.story.instruction))
    }

    @Test func theIdeaSheetHasItsOwnIdentity() {
        let seed = ScriptIdeaSeed(text: "x", idea: .tip)
        #expect(AppSheet.generateIdea(seed).id == "generateIdea")
        #expect(AppSheet.generateIdea(seed).id != AppSheet.generateScript(.prompt).id)
    }
}
