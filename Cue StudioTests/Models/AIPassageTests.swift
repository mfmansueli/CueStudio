//
//  AIPassageTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

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
