//
//  IdeaPromptDraftTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
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
        let pickedTip = draft.toggle(.tip)
        #expect(pickedTip)
        #expect(draft.idea == .tip)
        let pickedStory = draft.toggle(.story)
        #expect(pickedStory)
        #expect(draft.idea == .story)
        // Letting go goes back to a free idea and doesn't ask for the keyboard.
        let pickedAgain = draft.toggle(.story)
        #expect(!pickedAgain)
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

    // MARK: - Dictation

    @Test func dictationAddsAfterWhatWasTypedWithASpaceAndNeverErasesIt() {
        var draft = IdeaPromptDraft()
        draft.text = "A video about coffee"
        draft.beginDictation(caret: nil)
        // Starting writes nothing.
        #expect(draft.text == "A video about coffee")
        draft.hear("and the first hour")
        #expect(draft.text == "A video about coffee and the first hour")
    }

    @Test func partialResultsReplaceOnlyTheirOwnSegmentSoNothingRepeats() {
        var draft = IdeaPromptDraft()
        draft.text = "Morning routine."
        draft.beginDictation(caret: nil)
        for partial in ["a", "a quick", "a quick video", "a quick video for", "A quick video for TikTok"] {
            draft.hear(partial)
        }
        #expect(draft.text == "Morning routine. A quick video for TikTok")
    }

    @Test func aTranscriptThatShrinksBecauseTheRecognizerRewroteItIsStillOneSegment() {
        var draft = IdeaPromptDraft()
        draft.beginDictation(caret: nil)
        draft.hear("their going to the beach")
        draft.hear("they’re going to the beach")
        #expect(draft.text == "they’re going to the beach")
    }

    @Test func dictationGoesAtTheCaretWhenThereIsOne() {
        var draft = IdeaPromptDraft()
        draft.text = "Hello world"
        draft.beginDictation(caret: 6)
        draft.hear("big")
        #expect(draft.text == "Hello big world")
        draft.hear("big beautiful")
        #expect(draft.text == "Hello big beautiful world")
    }

    @Test func aCaretAtTheStartPutsTheWordsFirst() {
        var draft = IdeaPromptDraft()
        draft.text = "morning coffee"
        draft.beginDictation(caret: 0)
        draft.hear("A video about")
        #expect(draft.text == "A video about morning coffee")
    }

    @Test func aCaretOutOfRangeFallsBackToTheEndOrTheStart() {
        var draft = IdeaPromptDraft()
        draft.text = "abc"
        draft.beginDictation(caret: 99)
        draft.hear("def")
        #expect(draft.text == "abc def")
        var other = IdeaPromptDraft()
        other.text = "abc"
        other.beginDictation(caret: -4)
        other.hear("def")
        #expect(other.text == "def abc")
    }

    @Test func noSpaceIsAddedAfterWhitespaceOrANewlineOrBeforeClosingPunctuation() {
        var draft = IdeaPromptDraft()
        draft.text = "First line\n"
        draft.beginDictation(caret: nil)
        draft.hear("second line")
        #expect(draft.text == "First line\nsecond line")

        var spaced = IdeaPromptDraft()
        spaced.text = "Already spaced "
        spaced.beginDictation(caret: nil)
        spaced.hear("more")
        #expect(spaced.text == "Already spaced more")

        var punctuated = IdeaPromptDraft()
        punctuated.text = "Hello"
        punctuated.beginDictation(caret: nil)
        punctuated.hear(", world")
        #expect(punctuated.text == "Hello, world")

        var before = IdeaPromptDraft()
        before.text = "Hello."
        before.beginDictation(caret: 5)
        before.hear("there")
        #expect(before.text == "Hello there.")
    }

    @Test func writingWithoutSpacesIsNotBrokenApart() {
        var draft = IdeaPromptDraft()
        draft.text = "今日は"
        draft.beginDictation(caret: nil)
        draft.hear("天気がいい")
        #expect(draft.text == "今日は天気がいい")
    }

    @Test func anEmptyTranscriptLeavesTheTextAsItWas() {
        var draft = IdeaPromptDraft()
        draft.text = "Keep me"
        draft.beginDictation(caret: nil)
        draft.hear("  ")
        #expect(draft.text == "Keep me")
        draft.hear("more")
        draft.hear("")
        #expect(draft.text == "Keep me")
        #expect(draft.endDictation() == nil)
    }

    @Test func stoppingKeepsTheWordsAndSaysWhereTheyEnd() {
        var draft = IdeaPromptDraft()
        draft.text = "Hello world"
        draft.beginDictation(caret: 6)
        draft.hear("big")
        #expect(draft.endDictation() == 9)
        #expect(draft.dictation == nil)
        #expect(draft.text == "Hello big world")
        // After the end, a late result writes nothing.
        draft.hear("late")
        #expect(draft.text == "Hello big world")
    }

    @Test func eachDictationOwnsOnlyItsOwnWordsSoTheSecondNeverTouchesTheFirst() {
        var draft = IdeaPromptDraft()
        draft.beginDictation(caret: nil)
        draft.hear("first idea")
        draft.endDictation()
        draft.beginDictation(caret: nil)
        draft.hear("second idea")
        draft.hear("second idea, longer")
        draft.endDictation()
        #expect(draft.text == "first idea second idea, longer")
    }

    @Test func typingDuringADictationStopsItWritingSoItNeverOverwritesTheTyping() {
        var draft = IdeaPromptDraft()
        draft.text = "Start"
        draft.beginDictation(caret: nil)
        draft.hear("spoken words")
        // Something else changes the field (paste, autofill, Writing Tools).
        draft.text += " plus typed"
        draft.textChanged()
        #expect(draft.dictation == nil)
        draft.hear("spoken words continue")
        #expect(draft.text == "Start spoken words plus typed")
    }

    @Test func theDictationsOwnWritingIsNotMistakenForTyping() {
        var draft = IdeaPromptDraft()
        draft.text = "Start"
        draft.beginDictation(caret: nil)
        draft.hear("spoken")
        draft.textChanged()
        #expect(draft.dictation != nil)
        draft.hear("spoken words")
        #expect(draft.text == "Start spoken words")
    }

    @Test func aResultWithNoDictationRunningWritesNothing() {
        var draft = IdeaPromptDraft()
        draft.text = "Typed"
        draft.hear("stray")
        #expect(draft.text == "Typed")
    }

    @Test func nothingIsSentWhileADictationIsStillWriting() {
        var draft = IdeaPromptDraft()
        draft.text = "A finished thought"
        #expect(draft.canSubmit(isAvailable: true))
        #expect(!draft.canSubmit(isAvailable: true, isDictating: true))
    }

    @Test func aSpokenIdeaTakesTheSameRoadAsATypedOneWithTheKindKept() {
        var spoken = IdeaPromptDraft()
        spoken.toggle(.story)
        spoken.beginDictation(caret: nil)
        spoken.hear("why I quit coffee ")
        spoken.endDictation()
        var typed = IdeaPromptDraft()
        typed.toggle(.story)
        typed.text = "why I quit coffee"
        #expect(spoken.seed == typed.seed)
        #expect(spoken.seed == ScriptIdeaSeed(text: "why I quit coffee", idea: .story))
        // Picking a kind while it listens changes the question only.
        var listening = IdeaPromptDraft()
        listening.beginDictation(caret: nil)
        listening.hear("a product review")
        listening.toggle(.product)
        #expect(listening.text == "a product review" && listening.dictation != nil && listening.idea == .product)
    }

    @Test func theInsertionPointComesFromTheSelectionAndASelectedRangeIsAddedAfterNeverOver() {
        let text = "Hello world"
        #expect(IdeaPromptDraft.caretOffset(of: nil, in: text) == nil)
        let caret = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: 5))
        #expect(IdeaPromptDraft.caretOffset(of: caret, in: text) == 5)
        let range = TextSelection(range: text.index(text.startIndex, offsetBy: 6)..<text.endIndex)
        #expect(IdeaPromptDraft.caretOffset(of: range, in: text) == 11)
        // A selection from an older, longer text can't be used on a shorter one.
        let longer = "Hello world and more"
        let stale = TextSelection(insertionPoint: longer.endIndex)
        #expect(IdeaPromptDraft.caretOffset(of: stale, in: "Hi") == nil)
        var draft = IdeaPromptDraft()
        draft.text = text
        draft.beginDictation(caret: IdeaPromptDraft.caretOffset(of: range, in: text))
        draft.hear("again")
        #expect(draft.text == "Hello world again")
    }
}
