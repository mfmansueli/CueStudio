//
//  ScriptCueDeletionTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptCueDeletion")
struct ScriptCueDeletionTests {
    @Test func backspaceAfterACueTakesTheWholeCueAndOneSpace() {
        // Backspace right after "]".
        let result = ScriptCueDeletion.completing(from: "Okay, [pause] real talk.", to: "Okay, [pause real talk.")
        #expect(result == .init(text: "Okay, real talk.", caret: 6))
    }

    @Test func deletingInsideACueTakesAllOfIt() {
        let backspace = ScriptCueDeletion.completing(from: "Hi [smile] there", to: "Hi [smle] there")
        #expect(backspace == .init(text: "Hi there", caret: 3))
        // Forward delete on "[".
        let forward = ScriptCueDeletion.completing(from: "Hi [smile] there", to: "Hi smile] there")
        #expect(forward == .init(text: "Hi there", caret: 3))
    }

    @Test func aSelectionThatCutsIntoACueTakesTheCueToo() {
        // "at] t" selected and deleted: the rest of the cue goes, the rest of the word stays.
        let result = ScriptCueDeletion.completing(from: "One [beat] two three", to: "One [bewo three")
        #expect(result == .init(text: "One wo three", caret: 4))
    }

    @Test func aCueThatOpensOrClosesTheTextLeavesNoStraySpace() {
        #expect(ScriptCueDeletion.completing(from: "[pause] Go.", to: "[pause Go.") == .init(text: "Go.", caret: 0))
        #expect(ScriptCueDeletion.completing(from: "Go. [pause]", to: "Go. [pause") == .init(text: "Go. ", caret: 4))
    }

    @Test func deletionsThatDontTouchACueAreLeftAlone() {
        // The space after a cue.
        #expect(ScriptCueDeletion.completing(from: "Okay, [pause] real", to: "Okay, [pause]real") == nil)
        // Plain words, a whole cue at once, typing.
        #expect(ScriptCueDeletion.completing(from: "Hello world", to: "Hello worl") == nil)
        #expect(ScriptCueDeletion.completing(from: "Hi [smile] there", to: "Hi  there") == nil)
        #expect(ScriptCueDeletion.completing(from: "Hi [smile] there", to: "Hi [smile] there!") == nil)
        // A selection replaced by typing.
        #expect(ScriptCueDeletion.completing(from: "Hi [smile] there", to: "Hi [smX] there") == nil)
    }

    @Test func bracketsThatArentACueAreJustCharacters() {
        // An unclosed bracket, an empty pair and a pair across lines aren't cues.
        #expect(ScriptCueDeletion.completing(from: "Price [about", to: "Price [abou") == nil)
        #expect(ScriptCueDeletion.completing(from: "a [] b", to: "a [ b") == nil)
        #expect(ScriptCueDeletion.completing(from: "a [one\ntwo] b", to: "a [one\ntwo b") == nil)
        #expect(ScriptCueDeletion.cues(in: Array("[pause] x [look at camera]")) == [0..<7, 10..<26])
    }

    @Test func charactersCountAsThePageCountsThem() {
        // An emoji is one character, as the page's selection counts.
        let result = ScriptCueDeletion.completing(from: "😀 [pause] go", to: "😀 [paus] go")
        #expect(result == .init(text: "😀 go", caret: 2))
    }
}
