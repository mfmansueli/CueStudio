//
//  EditHistoryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditHistory")
struct EditHistoryTests {
    @Test func undoAndRedoWalkBackAndForth() {
        var history = EditHistory<Int>()
        // Original 0 → trim 1 → cut 2 → remove 3
        history.record(0)
        history.record(1)
        history.record(2)
        var current = 3
        current = history.undo(from: current) ?? current
        #expect(current == 2)
        current = history.undo(from: current) ?? current
        #expect(current == 1)
        current = history.undo(from: current) ?? current
        #expect(current == 0)
        #expect(!history.canUndo)
        #expect(history.undo(from: current) == nil)
        current = history.redo(from: current) ?? current
        current = history.redo(from: current) ?? current
        current = history.redo(from: current) ?? current
        #expect(current == 3)
        #expect(!history.canRedo)
    }

    @Test func aNewChangeForgetsWhatWasUndone() {
        var history = EditHistory<Int>()
        history.record(0)
        _ = history.undo(from: 1)
        #expect(history.canRedo)
        history.record(0)
        #expect(!history.canRedo)
    }

    @Test func keepsTheLatestSteps() {
        var history = EditHistory<Int>()
        for step in 0..<(EditHistory<Int>.limit + 20) { history.record(step) }
        #expect(history.past.count == EditHistory<Int>.limit)
        #expect(history.past.first == 20)
    }
}
