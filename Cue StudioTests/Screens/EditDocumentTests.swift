//
//  EditDocumentTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The edit and its undo steps on their own, without the editor: every decision is a step, a gesture is one, what listening
/// found never is, and a draft opens with its steps.
@MainActor
@Suite("Edit document")
struct EditDocumentTests {
    private static func text(_ title: String) -> TextOverlay {
        var text = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 0, end: 2))
        text.text = title
        return text
    }

    @Test func eachDecisionIsAStepAndTheEditorHearsIt() {
        let document = EditDocument(EditFixtures.blank())
        var heard: [Int] = []
        document.onChange = { previous in heard.append(previous.texts.count) }
        document.change { $0.texts.append(Self.text("One")) }
        document.change { $0.texts.append(Self.text("Two")) }
        #expect(document.edit.texts.count == 2)
        #expect(document.hasUnsavedChanges)
        #expect(document.undo())
        #expect(document.edit.texts.map(\.text) == ["One"])
        #expect(document.undo())
        #expect(!document.undo())
        #expect(!document.hasUnsavedChanges)
        #expect(document.redo())
        #expect(document.edit.texts.count == 1)
        #expect(heard == [0, 1, 2, 1, 0])
    }

    @Test func quickChangesOfOneKindAreOneStep() {
        let document = EditDocument(EditFixtures.blank())
        for exposure in [10.0, 20, 30] {
            document.changeEdit(key: "exposure") { $0.exposure = exposure }
        }
        document.changeEdit(key: "contrast") { $0.contrast = 5 }
        #expect(document.undo())
        #expect(document.edit.exposure == 30)
        #expect(document.undo())
        #expect(document.edit.exposure == 0)
        #expect(!document.canUndo)
    }

    @Test func aGestureIsOneStepFromWhereItBegan() {
        let document = EditDocument(EditFixtures.blank())
        document.beginChange()
        document.changeEdit { $0.cropOffset = 0.2 }
        document.changeEdit { $0.cropOffset = 0.7 }
        #expect(!document.canUndo)
        document.endChange()
        #expect(document.undo())
        #expect(document.edit.cropOffset == 0)
        #expect(!document.canUndo)
        // A gesture that ends where it began leaves no step.
        document.beginChange()
        document.changeEdit { $0.cropOffset = 0.4 }
        document.changeEdit { $0.cropOffset = 0 }
        document.endChange()
        #expect(document.canRedo)
        #expect(!document.canUndo)
    }

    @Test func whatListeningFoundIsNoStepAndUndoKeepsIt() {
        let document = EditDocument(EditFixtures.blank())
        document.change { $0.texts.append(Self.text("Hook")) }
        let found = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 3, end: 4), confidence: 0.9)
        document.updateFindings { edit in
            edit.suggestions = [found]
            edit.cleanUpAnalyzed = true
        }
        #expect(document.history.past.count == 1)
        #expect(document.undo())
        #expect(document.edit.texts.isEmpty)
        #expect(document.edit.cleanUpAnalyzed)
        // Found after the step undone: still there, waiting for review.
        #expect(document.edit.suggestions.map(\.id) == [found.id])
        #expect(document.edit.suggestions.first?.status == .pending)
    }

    @Test func aSuggestionsDecisionGoesBackWithItsStep() {
        var start = EditFixtures.blank()
        start.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 3, end: 4), confidence: 0.9)]
        let document = EditDocument(start)
        var decided = document.edit.suggestions
        decided[0].status = .kept
        document.commit(document.edit.timeline, suggestions: decided)
        #expect(document.edit.suggestions.first?.status == .kept)
        document.undo()
        #expect(document.edit.suggestions.first?.status == .pending)
    }

    @Test func aDraftLeftBehindOpensWithItsSteps() {
        var saved = EditFixtures.blank()
        saved.timeline = EditTimeline(sourceDuration: 30)
        let document = EditDocument(saved)
        var history = EditHistory<EditSnapshot>()
        history.record(EditSnapshot(EditFixtures.blank()))
        var drafted = EditFixtures.blank()
        drafted.texts = [Self.text("Draft")]
        drafted.timeline = EditTimeline(sourceDuration: 30)
        let draft = QuickEditDraft(takeID: UUID(), edit: drafted, playhead: 2, history: history, savedAt: .now)
        #expect(document.open(sourceDuration: EditFixtures.duration, draft: draft))
        #expect(document.edit.texts.map(\.text) == ["Draft"])
        #expect(document.edit.timeline.editedDuration == EditFixtures.duration)
        #expect(document.original.timeline.editedDuration == EditFixtures.duration)
        #expect(document.canUndo)
        #expect(document.hasUnsavedChanges)
    }

    @Test func aDraftLikeTheTakesEditIsLeftAlone() {
        let blank = EditFixtures.blank()
        let document = EditDocument(blank)
        var history = EditHistory<EditSnapshot>()
        history.record(EditSnapshot(EditFixtures.everything()))
        let draft = QuickEditDraft(takeID: UUID(), edit: blank, playhead: 0, history: history, savedAt: .now)
        #expect(!document.open(sourceDuration: EditFixtures.duration, draft: draft))
        #expect(!document.canUndo)
        #expect(!document.hasUnsavedChanges)
    }
}
