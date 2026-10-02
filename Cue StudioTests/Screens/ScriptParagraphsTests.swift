//
//  ScriptParagraphsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptParagraphs")
struct ScriptParagraphsTests {
    @Test func aScriptIsItsLinesAndNeverNone() {
        #expect(ScriptParagraphs.split("One.\n\nTwo.\nThree.") == ["One.", "Two.", "Three."])
        #expect(ScriptParagraphs.split("") == [""])
        #expect(ScriptParagraphs.split("  \n \n") == [""])
    }

    @Test func savingKeepsWhatSaysSomethingAndTrimsIt() {
        #expect(ScriptParagraphs.join(["  One. ", "", "Two.", "   "]) == "One.\n\nTwo.")
        #expect(ScriptParagraphs.join([""]) == "")
    }

    @Test func aBreakInTheMiddleSplitsAndTheCaretStartsTheSecondHalf() {
        let edit = ScriptParagraphs.replacing(paragraphAt: 1, with: "Two\nand a half.", caret: 4, in: ["One.", "Twoand a half.", "Three."])
        #expect(edit.paragraphs == ["One.", "Two", "and a half.", "Three."])
        #expect(edit.caret == ScriptParagraphs.Caret(index: 2, offset: 0))
    }

    @Test func aPasteWithSeveralLinesLeavesTheCaretAtTheEndOfTheLastOne() {
        // "x" + a pasted "a\nb\nc" at its end.
        let edit = ScriptParagraphs.replacing(paragraphAt: 0, with: "xa\nb\nc", caret: 6, in: ["x"])
        #expect(edit.paragraphs == ["xa", "b", "c"])
        #expect(edit.caret == ScriptParagraphs.Caret(index: 2, offset: 1))
    }

    @Test func aBreakAtTheEndMakesAnEmptyParagraphToWriteIn() {
        let edit = ScriptParagraphs.replacing(paragraphAt: 0, with: "Done.\n", caret: 6, in: ["Done."])
        #expect(edit.paragraphs == ["Done.", ""])
        #expect(edit.caret == ScriptParagraphs.Caret(index: 1, offset: 0))
    }

    @Test func backspaceAtTheStartJoinsWithASpaceOnlyWhenBothSaySomething() throws {
        let joined = try #require(ScriptParagraphs.mergingWithPrevious(1, in: ["Hello", "world."]))
        #expect(joined.paragraphs == ["Hello world."])
        #expect(joined.caret == ScriptParagraphs.Caret(index: 0, offset: 6))
        let afterEmpty = try #require(ScriptParagraphs.mergingWithPrevious(1, in: ["", "world."]))
        #expect(afterEmpty.paragraphs == ["world."])
        #expect(afterEmpty.caret == ScriptParagraphs.Caret(index: 0, offset: 0))
        let ofEmpty = try #require(ScriptParagraphs.mergingWithPrevious(1, in: ["Hello", ""]))
        #expect(ofEmpty.paragraphs == ["Hello"])
        #expect(ofEmpty.caret == ScriptParagraphs.Caret(index: 0, offset: 5))
        #expect(ScriptParagraphs.mergingWithPrevious(0, in: ["Hello"]) == nil)
    }

    @Test func aCueGetsASpaceBeforeItUnlessOneIsThere() {
        let mid = ScriptParagraphs.cue("pause", atOffset: 5, inParagraph: 0, of: ["Okay, real talk."])
        #expect(mid.paragraphs == ["Okay, [pause]  real talk."])
        let afterSpace = ScriptParagraphs.cue("smile", atOffset: 6, inParagraph: 0, of: ["Okay, real talk."])
        #expect(afterSpace.paragraphs == ["Okay, [smile] real talk."])
        #expect(afterSpace.caret.offset == 6 + "[smile] ".utf16.count)
        let start = ScriptParagraphs.cue("beat", atOffset: 0, inParagraph: 0, of: ["Hi."])
        #expect(start.paragraphs == ["[beat] Hi."])
    }

    @Test func offsetsPastTheEndAreHeldAtTheEnd() {
        let edit = ScriptParagraphs.inserting("!", atOffset: 99, inParagraph: 0, of: ["Hey"])
        #expect(edit.paragraphs == ["Hey!"])
        #expect(edit.caret.offset == 4)
        let split = ScriptParagraphs.splitting(paragraphAt: 0, atOffset: 99, in: ["Hey"])
        #expect(split.paragraphs == ["Hey", ""])
    }

    @Test func emojiAreMeasuredTheWayTextViewsMeasureThem() {
        // 😀 is two UTF-16 units: the caret after it is at 2, and a break there splits cleanly.
        let edit = ScriptParagraphs.replacing(paragraphAt: 0, with: "😀\nhi", caret: 3, in: ["😀hi"])
        #expect(edit.paragraphs == ["😀", "hi"])
        #expect(edit.caret == ScriptParagraphs.Caret(index: 1, offset: 0))
    }
}
