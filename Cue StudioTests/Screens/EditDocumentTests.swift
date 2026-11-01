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

    /// B20: a draft left open while an export heard the take keeps those captions when it is picked up again (and its undo steps don't take
    /// them away); a draft whose captions the creator removed keeps them removed.
    @Test func aDraftPickedUpAgainTakesInTheCaptionsAnExportHeard() {
        var finished = EditFixtures.blank()
        finished.captions = [CaptionCue(text: "Okay, real talk.", start: 0, end: 1.5)]
        finished.captionTranscript = CaptionTranscript(words: [], languageCode: "en")
        var left = EditFixtures.blank()
        left.texts.append(Self.text("Mine"))
        var history = EditHistory<EditSnapshot>()
        var before = EditSnapshot(EditFixtures.blank())
        before.captions = []
        history.record(before)
        let draft = QuickEditDraft(takeID: UUID(), edit: left, playhead: 0, history: history, savedAt: .now)
        let document = EditDocument(finished)
        #expect(document.open(sourceDuration: finished.timeline.sourceDuration, draft: draft))
        #expect(document.edit.captions.map(\.text) == ["Okay, real talk."])
        #expect(document.edit.captionTranscript != nil)
        #expect(document.edit.texts.map(\.text) == ["Mine"])
        #expect(document.undo())
        #expect(document.edit.captions.map(\.text) == ["Okay, real talk."], "undoing the draft's steps never takes them away")

        var removed = left
        removed.captionTranscript = CaptionTranscript(words: [], languageCode: "en")
        let theirs = EditDocument(finished)
        theirs.open(
            sourceDuration: finished.timeline.sourceDuration,
            draft: QuickEditDraft(takeID: UUID(), edit: removed, playhead: 0, history: EditHistory<EditSnapshot>(), savedAt: .now)
        )
        #expect(theirs.edit.captions.isEmpty, "lines the creator removed stay removed")
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

    /// A panel's slider held while a finger drags a handle: one step, taken when both have let go, and one ending never ends
    /// the other's. Undo ends whatever is still going.
    @Test func twoChangesAtOnceAreOneStepTakenWhenBothEnd() {
        let document = EditDocument(EditFixtures.blank())
        document.beginChange(by: .panel)
        document.changeEdit { $0.exposure = 20 }
        document.beginChange(by: .gesture)
        document.changeEdit { $0.cropOffset = 0.5 }
        document.endChange(by: .gesture)
        #expect(!document.canUndo)
        document.changeEdit { $0.exposure = 30 }
        // A late "let go" of something else never closes the slider's step.
        document.endChange(by: .gesture)
        #expect(!document.canUndo)
        document.endChange(by: .panel)
        #expect(document.undo())
        #expect(document.edit.exposure == 0)
        #expect(document.edit.cropOffset == 0)
        #expect(!document.canUndo)
        document.redo()
        document.beginChange(by: .panel)
        document.changeEdit { $0.exposure = 50 }
        #expect(document.undo())
        #expect(document.edit.exposure == 30)
        #expect(document.changeOwners.isEmpty)
    }

    /// The app left in the middle of a drag: the draft's steps take the gesture as a step of its own, so the edit saved with
    /// them goes back to where the gesture began on Undo, even after the draft is read twice.
    @Test func aDraftSavedMidGestureKeepsTheGestureAsAStep() {
        let document = EditDocument(EditFixtures.blank())
        document.changeEdit { $0.exposure = 10 }
        document.beginChange()
        document.changeEdit { $0.exposure = 40 }
        #expect(document.history.past.count == 1)
        let saved = document.draftHistory
        #expect(saved.past.count == 2)
        var history = saved
        let undone = history.undo(from: document.snapshot)
        var edit = document.edit
        if let undone { edit.apply(undone) }
        #expect(edit.exposure == 10)
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
