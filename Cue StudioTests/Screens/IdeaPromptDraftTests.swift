//
//  IdeaPromptDraftTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

/// The empty Scripts screen's idea card: one draft, shared by the card, the composer and the
/// generation flow, and nothing is sent from an empty field or while a dictation is still writing.
@MainActor
@Suite("Idea prompt card")
struct IdeaPromptDraftTests {
    @Test func nothingIsSentFromAnEmptyFieldOrOneWithOnlySpaces() {
        var draft = IdeaPromptDraft()
        #expect(!draft.canSubmit(isAvailable: true) && draft.submission == nil)
        draft.text = "  \n  "
        #expect(!draft.canSubmit(isAvailable: true) && draft.submission == nil)
    }

    @Test func theTextIsSentWithoutTheSpacesAroundIt() {
        var draft = IdeaPromptDraft()
        draft.text = "  Three ways to focus  "
        #expect(draft.canSubmit(isAvailable: true))
        #expect(draft.submission == "Three ways to focus")
    }

    @Test func withoutAModelTheArrowStaysOffEvenWithText() {
        var draft = IdeaPromptDraft()
        draft.text = "Three ways to focus"
        #expect(!draft.canSubmit(isAvailable: false))
    }

    /// With nothing written the arrow asks for ideas instead ("Need an idea?"), with or without a
    /// model (the ideas are local), but never while a dictation is still writing, and never with an idea
    /// already typed: then it sends.
    @Test func withNothingWrittenTheArrowAsksForIdeas() {
        var draft = IdeaPromptDraft()
        #expect(draft.canAskForIdea())
        draft.text = "  \n "
        #expect(draft.canAskForIdea())
        #expect(!draft.canAskForIdea(isDictating: true))
        draft.text = "Three ways to focus"
        #expect(!draft.canAskForIdea())
        #expect(draft.canSubmit(isAvailable: true))
    }

    @Test func theServiceAsksForIdeasOnlyWhileTheDraftIsEmpty() {
        let service = IdeaDraftService()
        #expect(service.canAskForIdea(isDictating: false))
        service.text = "Carnival in Salvador"
        #expect(!service.canAskForIdea(isDictating: false))
        service.clear()
        #expect(service.canAskForIdea(isDictating: false))
    }

    // MARK: - One draft

    @Test func theServiceIsTheOneCopyOfTheText() {
        let service = IdeaDraftService()
        #expect(service.isEmpty && service.submission == nil)
        service.text = "  Carnival in Salvador  "
        #expect(service.text == "  Carnival in Salvador  ")
        #expect(service.submission == "Carnival in Salvador")
        #expect(service.canSubmit(isAvailable: true, isDictating: false))
        #expect(!service.canSubmit(isAvailable: true, isDictating: true))
        service.clear()
        #expect(service.isEmpty && service.text.isEmpty)
    }

    @Test func theIdeaSheetsHaveTheirOwnIdentity() {
        let ids = [AppSheet.ideas.id, AppSheet.format.id, AppSheet.createFor.id, AppSheet.newScript.id]
        #expect(Set(ids).count == ids.count)
    }

    @Test func clearingTheDraftBringsBackTheDefaultsIncludingTheFormat() {
        let service = IdeaDraftService()
        service.text = "Carnival in Salvador"
        service.platform = .reels
        service.length = .minutes2
        service.format = .review
        service.clear()
        #expect(service.isEmpty && service.platform == nil && service.length == .auto && service.format == nil)
    }

    @Test func aDictationEndingAfterTheComposerClosedStillWritesIntoTheDraft() {
        let service = IdeaDraftService()
        service.text = "Carnival"
        service.beginDictation(caret: nil)
        service.hear("in Salvador")
        // The sheet is gone; the last words arrive later.
        service.hear("in Salvador, with the trios")
        #expect(service.text == "Carnival in Salvador, with the trios")
        #expect(service.endDictation() == 36)
        service.hear("late")
        #expect(service.text == "Carnival in Salvador, with the trios")
    }

    @Test func typingInTheComposerEndsADictationThatWasStillWriting() {
        let service = IdeaDraftService()
        service.beginDictation(caret: nil)
        service.hear("spoken")
        service.text = "spoken and typed"
        service.hear("spoken words")
        #expect(service.text == "spoken and typed")
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

    @Test func aSpokenIdeaTakesTheSameRoadAsATypedOne() {
        var spoken = IdeaPromptDraft()
        spoken.beginDictation(caret: nil)
        spoken.hear("why I quit coffee ")
        spoken.endDictation()
        var typed = IdeaPromptDraft()
        typed.text = "why I quit coffee"
        #expect(spoken.submission == typed.submission)
        #expect(spoken.submission == "why I quit coffee")
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
