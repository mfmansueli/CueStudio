//
//  ScriptShapeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Shaped side of the script page: sections, the advice, and the fixes that go with it.
@Suite("Script shape")
struct ScriptShapeTests {
    private let speed = 0.7

    private func shape(_ text: String, structure: ScriptStructure = .generic) -> ScriptShape {
        ScriptShape(text: text, structure: structure, speed: speed)
    }

    @Test func aTalkingVideoHasHookBodyAndCTAWhenItClosesOnACallToAction() {
        let result = shape("Okay, real talk.\n\nFirst point.\n\nSecond point.\n\nFollow for part two.")
        #expect(result.sections.map(\.label) == ["Hook", "Body", "CTA"])
        #expect(result.sections[1].paragraphs.count == 2)
        #expect(result.sections.allSatisfy { !$0.isMissingCTA })
        #expect(result.sections[0].isHook && !result.sections[1].isHook)
    }

    @Test func aScriptThatDoesntCloseOnACallToActionSaysSo() {
        let result = shape("Okay, real talk.\n\nFirst point.\n\nSecond point.")
        // The last paragraph is body, and an empty CTA is offered.
        #expect(result.sections.map(\.label) == ["Hook", "Body", "CTA"])
        #expect(result.sections[1].paragraphs.count == 2)
        #expect(result.sections[2].isMissingCTA && result.sections[2].paragraphs.isEmpty)
    }

    @Test func anEmptyScriptHasNoSectionsAndNothingMissing() {
        #expect(shape("").sections.isEmpty)
        #expect(shape("  \n ").sections.isEmpty)
    }

    @Test func aLongOpeningSentenceIsAHookTip() {
        let hook = "Okay so listen " + TestData.words(30) + " done."
        let result = shape(hook + "\n\nBody.\n\nFollow me.")
        guard case .longHook(let seconds)? = result.hookTip else {
            Issue.record("Expected a long-hook tip")
            return
        }
        #expect(seconds > 3)
    }

    @Test func aShortHookHasNoTip() {
        #expect(shape("Okay, real talk.\n\nBody.\n\nFollow me.").hookTip == nil)
    }

    @Test func aSeriousFormatHasNoHookAndNoHookTip() {
        let structure = ScriptType.apology.structure
        let result = shape(TestData.words(40) + ".\n\nWe own it.\n\nThis is what changes.", structure: structure)
        #expect(result.hookTip == nil)
        #expect(result.sections.allSatisfy { !$0.isHook })
    }

    @Test func aVeryLongBodySentenceIsASplitTip() {
        let long = "This sentence goes on " + TestData.words(26) + ", and then some more."
        let result = shape("Hook.\n\n" + long + "\n\nFollow me.")
        #expect(result.bodyTip == .longSentence(long))
    }

    @Test func fixingTheHookKeepsItsFirstEightWordsAndTheRestOfTheText() {
        let text = "One two three four five six seven eight nine ten, eleven twelve.\n\nBody here.\n\nFollow me."
        let fixed = ScriptShape.shortenedHook(in: text)
        #expect(fixed.hasPrefix("One two three four five six seven eight."))
        #expect(fixed.hasSuffix("Body here.\n\nFollow me."))
        #expect(!fixed.contains("eleven"))
    }

    @Test func splittingASentenceBreaksItAtItsFirstComma() {
        let sentence = "This is long, and so is this part."
        let split = ScriptShape.splitting(sentence, in: "Hook.\n\n" + sentence)
        #expect(split == "Hook.\n\nThis is long. and so is this part.")
    }

    @Test func suggestingACTAAddsOneLineAtTheEnd() {
        let text = ScriptShape.addingCTA(to: "Hook.\n\nBody.\n")
        #expect(text.hasPrefix("Hook.\n\nBody.\n"))
        #expect(text.hasSuffix(ScriptShape.suggestedCTA))
        #expect(shape(text).sections.last?.label == "CTA")
    }

    @Test func tipsHaveStableIdentitiesForDismissing() {
        #expect(ScriptShape.Tip.longHook(seconds: 5).id == ScriptShape.Tip.longHook(seconds: 9).id)
        #expect(ScriptShape.Tip.longHook(seconds: 5).id != ScriptShape.Tip.longSentence("x").id)
    }
}
