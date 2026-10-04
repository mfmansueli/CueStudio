//
//  ScriptStripTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The state strip (v29 · 4.1) in every state of 04 · F2.
@Suite("Script strip")
struct ScriptStripTests {
    private func take(_ script: Script, number: Int, version: Int = 1) -> Take {
        var take = TestData.take(scriptID: script.id, number: number)
        take.scriptVersion = version
        return take
    }

    @Test func aReadyScriptShowsItsFormatAndCuesAndOffersShapeWhenThereAreNone() {
        let script = TestData.script(text: "Words with no cues at all.", type: .list)
        let strip = ScriptStrip(script: script, takes: [], hasAI: true, isEdited: false)
        #expect(strip.state == .ready)
        #expect(strip.info == ["Tips / list", "No cues"])
        #expect(strip.canShape && strip.showsDone && !strip.recordsAgain && strip.recordIsPrimary)
    }

    @Test func shapeIsNotOfferedWithCuesOrWithoutAI() {
        let withCues = TestData.script(text: "Hook. [pause] Body. [smile]")
        #expect(!ScriptStrip(script: withCues, takes: [], hasAI: true, isEdited: false).canShape)
        #expect(ScriptStrip(script: withCues, takes: [], hasAI: true, isEdited: false).info.last == "2 cues")
        let none = TestData.script(text: "No cues here.")
        #expect(!ScriptStrip(script: none, takes: [], hasAI: false, isEdited: false).canShape)
    }

    @Test func aDraftSaysEditedUntilDone() {
        let draft = TestData.script(text: "Some words", isFinished: false)
        let strip = ScriptStrip(script: draft, takes: [], hasAI: true, isEdited: true)
        #expect(strip.state == .draft)
        #expect(strip.info == ["Edited", "Tap Done"])
        #expect(strip.showsDone)
    }

    @Test func aScriptWithNoFormatSaysYourScript() {
        let strip = ScriptStrip(script: TestData.script(text: "Hi [pause]"), takes: [], hasAI: true, isEdited: false)
        #expect(strip.info == ["Your script", "1 cue"])
    }

    @Test func aRecordedScriptOffersRetakeAndNoDone() {
        let script = TestData.script(text: "Words", isFinished: false)
        let strip = ScriptStrip(script: script, takes: [take(script, number: 1)], hasAI: true, isEdited: false)
        #expect(strip.state == .recorded)
        #expect(!strip.showsDone && strip.recordsAgain)
        #expect(!strip.recordIsPrimary, "unchanged since its take: the record button stays quiet")
        #expect(!strip.isSignal)
    }

    @Test func aRecordedScriptThatChangedSaysSoInYellowAndRetakeBecomesThePrimary() {
        var script = TestData.script(text: "Words")
        script.version = 2
        let strip = ScriptStrip(script: script, takes: [take(script, number: 1), take(script, number: 3)], hasAI: true, isEdited: true)
        #expect(strip.changedSinceTake == 3)
        #expect(strip.info == ["Changed since take 3"])
        #expect(strip.isSignal && strip.recordIsPrimary)
    }
}

@Suite("Script page rules")
struct ScriptPageRulesTests {
    @Test func doneWithNoTextSavesNothing() {
        #expect(ScriptPageRules.done(text: "  \n ", type: .tutorial) == .nothingToSave)
    }

    @Test func aFormatWithEmptySectionsAsksAndAScriptWithNoFormatDoesNot() {
        #expect(ScriptPageRules.done(text: "Hook only.", type: .tutorial) == .confirmEmptySections(3))
        #expect(ScriptPageRules.done(text: "Hook only.", type: nil) == .finish)
        #expect(ScriptPageRules.done(text: "One.\n\nTwo.\n\nThree.\n\nFour.", type: .tutorial) == .finish)
    }

    @Test func emptySectionsAreTheFormatsSectionsMinusTheParagraphsWritten() {
        #expect(ScriptPageRules.emptySections(text: "A.\n\nB.", type: .pov) == 1)
        #expect(ScriptPageRules.emptySections(text: "A.\n\nB.\n\nC.\n\nD.\n\nE.", type: .pov) == 0)
    }

    @Test func leavingWithEditsMakesADraftExceptAfterATake() {
        #expect(ScriptPageRules.leavesAsDraft(state: .ready, wasEdited: true))
        #expect(ScriptPageRules.leavesAsDraft(state: .draft, wasEdited: true))
        #expect(!ScriptPageRules.leavesAsDraft(state: .recorded, wasEdited: true))
        #expect(!ScriptPageRules.leavesAsDraft(state: .ready, wasEdited: false))
    }
}

@Suite("ScriptCueShaper")
struct ScriptCueShaperTests {
    @Test func aScriptWithNoCuesGetsUpToFourAndKeepsEveryWord() {
        let text = "First hook line. More hook.\n\nThe point is here. Another.\n\nTry it out. Follow me."
        let result = ScriptCueShaper.shaped(text)
        #expect(result.added == 4)
        #expect(CueParser.count(in: result.text) == 4)
        #expect(CueParser.stripCues(result.text).replacingOccurrences(of: "  ", with: " ").split(whereSeparator: \.isWhitespace)
            == text.split(whereSeparator: \.isWhitespace))
    }

    @Test func aScriptThatHasCuesIsLeftAlone() {
        let text = "Hook. [pause] Body."
        #expect(ScriptCueShaper.shaped(text) == .init(text: text, added: 0))
    }

    @Test func aShortScriptGetsOnlyWhatFits() {
        let result = ScriptCueShaper.shaped("Just one line here.")
        #expect(result.added == 1)
        #expect(result.text.contains("[pause]"))
        #expect(ScriptCueShaper.shaped("").added == 0)
    }

    @Test func theHooksPauseComesRightAfterTheHook() {
        let result = ScriptCueShaper.shaped("Stop scrolling. Here is why.\n\nBody text. More.")
        #expect(result.text.hasPrefix("Stop scrolling. [pause] Here is why."))
    }
}

@Suite("AIPassage")
struct AIPassageTests {
    @Test func undoPutsTheOldWordsWhereTheNewOnesAre() {
        let passage = AIPassage(action: .shorter, original: "a long sentence", replacement: "short", range: 6..<11)
        #expect(passage.undone(in: "Hello short world") == "Hello a long sentence world")
    }

    @Test func undoFindsTheNewWordsEvenWhenTheCreatorTypedBefore() {
        let passage = AIPassage(action: .rewrite, original: "old", replacement: "new words", range: 0..<9)
        #expect(passage.undone(in: "Added. new words end") == "Added. old end")
    }

    @Test func undoLeavesTheTextAloneWhenTheNewWordsAreGone() {
        let passage = AIPassage(action: .rewrite, original: "old", replacement: "new", range: 0..<3)
        #expect(passage.undone(in: "something else") == "something else")
    }
}
