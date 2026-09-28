//
//  QuickEditViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("QuickEditViewModel")
struct QuickEditViewModelTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let takes: TakeLibraryService
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let drafts: FakeDraftStore
        let toast: ToastService
    }

    private func makeScenario(
        script: Script? = TestData.script(text: "Okay, real talk."),
        editor: FakeTakeEditor = FakeTakeEditor(),
        drafts: FakeDraftStore = FakeDraftStore(),
        takes: TakeLibraryService? = nil
    ) async -> Scenario {
        var take = TestData.take(scriptID: script?.id, number: 3)
        take.duration = 64
        let takes = takes ?? {
            let service = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
            service.load()
            return service
        }()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: drafts, toast: toast, player: player
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, takes: takes, editor: editor, player: player, drafts: drafts, toast: toast)
    }

    private func spans(_ viewModel: QuickEditViewModel) -> [[TimeInterval]] {
        viewModel.edit.keptSpans.map { [$0.start, $0.end] }
    }

    private func dragHandle(_ handle: TrimHandle, to time: TimeInterval, on viewModel: QuickEditViewModel) {
        viewModel.beginTrim(handle)
        viewModel.trim(handle, toSource: time)
        viewModel.endTrim()
    }

    // MARK: - Opening

    @Test func startsFromTheWholeTake() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.source == .ready)
        #expect(scenario.viewModel.durationChange == "1:04 → 1:04")
        #expect(scenario.viewModel.timeLabel == "00:00:00 / 00:01:04")
        #expect(scenario.viewModel.edit.aspect == .portrait)
        #expect(scenario.player.shown.last == scenario.viewModel.edit)
    }

    @Test func aMissingRecordingCantBeEdited() async {
        let editor = FakeTakeEditor()
        editor.duration = nil
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.source == .unavailable)
        #expect(!scenario.viewModel.isReady)
        scenario.viewModel.cut()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.viewModel.cancel())
    }

    @Test func theFilesLengthWinsOverTheSavedOne() async {
        let editor = FakeTakeEditor()
        editor.duration = 64.4
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.edit.sourceDuration == 64.4)
        #expect(scenario.viewModel.edit.editedDuration == 64.4)
        #expect(!scenario.viewModel.hasUnsavedChanges)
    }

    // MARK: - Trim

    @Test func handlesTrimAndTheirPlayheadFollows() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 1)
        dragHandle(.start, to: 2, on: scenario.viewModel)
        #expect(scenario.viewModel.edit.timeline.trimStart == 2)
        #expect(scenario.player.currentTime == 0)
        scenario.player.seek(to: 60)
        dragHandle(.end, to: 9, on: scenario.viewModel)
        #expect(spans(scenario.viewModel) == [[2, 9]])
        #expect(scenario.player.currentTime == 7)
        #expect(scenario.viewModel.timeLabel == "00:00:07 / 00:00:07")
        #expect(!scenario.player.isScrubbing)
    }

    @Test func aHandleDragIsOneUndoStepAndHandlesNeverCross() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.beginTrim(.start)
        #expect(viewModel.activeHandle == .start)
        #expect(!viewModel.canUndo)
        for time in [5.0, 20, 80] { viewModel.trim(.start, toSource: time) }
        viewModel.endTrim()
        #expect(viewModel.activeHandle == nil)
        #expect(viewModel.edit.timeline.trimStart < viewModel.edit.timeline.trimEnd)
        #expect(viewModel.history.past.count == 1)
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
    }

    @Test func aHandleOnlyMovesWhileItsDragIsOn() async {
        let scenario = await makeScenario()
        scenario.viewModel.trim(.start, toSource: 10)
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    // MARK: - Cut and remove

    @Test func cutSplitsAtThePlayhead() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        #expect(spans(scenario.viewModel) == [[0, 20], [20, 64]])
        #expect(scenario.viewModel.edit.editedDuration == 64)
        #expect(scenario.toast.message == "Cut at 00:00:20")
    }

    @Test func cuttingAtAnEdgeExplains() async {
        let scenario = await makeScenario()
        scenario.viewModel.cut()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move the playhead away from the edges to cut")
    }

    @Test func removingTheSelectedPiece() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        scenario.viewModel.tapTimeline(onPiece: 1)
        #expect(scenario.viewModel.canRemoveSelection)
        scenario.viewModel.removeSelection()
        #expect(spans(scenario.viewModel) == [[0, 20]])
        #expect(scenario.viewModel.durationChange == "1:04 → 0:20")
        #expect(scenario.viewModel.selectedSegmentID == nil)
        #expect(scenario.toast.message == "Piece removed")
        #expect(scenario.player.shown.last?.keptSpans == [TimeSpan(start: 0, end: 20)])
    }

    @Test func removeNeedsASelectionAndKeepsOnePiece() async {
        let scenario = await makeScenario()
        scenario.viewModel.removeSelection()
        #expect(scenario.toast.message == "Tap a piece to select it")
        scenario.viewModel.tapTimeline(onPiece: 0)
        #expect(!scenario.viewModel.canRemoveSelection)
        scenario.viewModel.removeSelection()
        #expect(scenario.toast.message == "Keep at least one piece")
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    @Test func removingBAndDLeavesAAndC() async {
        let scenario = await makeScenario()
        for cut in [16.0, 32, 48] {
            scenario.player.seek(to: cut)
            scenario.viewModel.cut()
        }
        scenario.viewModel.tapTimeline(onPiece: 3)
        scenario.viewModel.removeSelection()
        scenario.viewModel.tapTimeline(onPiece: 1)
        scenario.viewModel.removeSelection()
        #expect(spans(scenario.viewModel) == [[0, 16], [32, 48]])
        #expect(scenario.viewModel.edit.editedDuration == 32)
    }

    @Test func theSelectionIsNotThePlayhead() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        scenario.viewModel.tapTimeline(onPiece: 0)
        scenario.viewModel.scrub(to: 40)
        scenario.viewModel.endScrub()
        #expect(scenario.viewModel.selectedSegmentIndex == 0)
        scenario.viewModel.tapTimeline(onPiece: nil)
        #expect(scenario.viewModel.selectedSegmentID == nil)
    }

    @Test func scrubbingPausesAndMovesThePlayhead() async {
        let scenario = await makeScenario()
        scenario.viewModel.togglePlayback()
        #expect(scenario.player.isPlaying)
        scenario.viewModel.scrub(to: 6.18)
        #expect(!scenario.player.isPlaying)
        #expect(scenario.player.currentTime == 6.18)
        scenario.viewModel.endScrub()
        #expect(!scenario.player.isPlaying)
    }

    @Test func removingAnEarlierPieceKeepsThePlayheadOnItsFrame() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 10)
        scenario.viewModel.cut()
        scenario.player.seek(to: 30)
        scenario.viewModel.tapTimeline(onPiece: 0)
        scenario.viewModel.removeSelection()
        #expect(scenario.player.currentTime == 20)
    }

    // MARK: - Undo

    @Test func undoAndRedoWalkThroughTrimCutAndRemove() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 4, on: viewModel)
        scenario.player.seek(to: 16)
        viewModel.cut()
        viewModel.tapTimeline(onPiece: 1)
        viewModel.removeSelection()
        #expect(spans(viewModel) == [[4, 20]])

        viewModel.undo()
        #expect(spans(viewModel) == [[4, 20], [20, 64]])
        viewModel.undo()
        #expect(spans(viewModel) == [[4, 64]])
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
        #expect(!viewModel.canUndo)

        viewModel.redo()
        viewModel.redo()
        viewModel.redo()
        #expect(spans(viewModel) == [[4, 20]])
        #expect(!viewModel.canRedo)
    }

    @Test func undoLeavesTheLookAlone() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.edit.filter = .mono
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.edit.filter == .mono)
    }

    // MARK: - Clean Up

    @Test func removeSilencesThenPutThemBack() async {
        let scenario = await makeScenario()
        await scenario.viewModel.reviewCleanUp()
        #expect(scenario.viewModel.showsCleanUp)
        #expect(scenario.viewModel.silenceLabel == "Remove silences · 2")
        // Finding pauses removes nothing: they're suggestions.
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.pausesLeftToRemove == 2)

        scenario.viewModel.removeAllPauses()
        #expect(scenario.viewModel.silencesAreRemoved)
        #expect(scenario.viewModel.silenceLabel == "Silences removed · −3s")
        #expect(scenario.viewModel.edit.editedDuration == 61)
        #expect(scenario.viewModel.pausesLeftToRemove == 0)
        scenario.viewModel.restoreRemovedPauses()
        #expect(scenario.viewModel.silenceLabel == "Remove silences · 2")
        #expect(scenario.viewModel.edit.timeline.isWhole)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.silencesAreRemoved)
    }

    @Test func noPausesExplains() async {
        let editor = FakeTakeEditor()
        editor.silences = []
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.reviewCleanUp()
        #expect(!scenario.viewModel.showsCleanUp)
        #expect(scenario.toast.message == "No long pauses in this take")
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    @Test func aTakeThatCantBeHeardSaysSo() async {
        let editor = FakeTakeEditor()
        editor.silencesFail = true
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.reviewCleanUp()
        #expect(!scenario.viewModel.showsCleanUp)
        #expect(scenario.toast.message == "Couldn't listen to this take")
    }

    @Test func eachPauseCanBeRemovedOrKept() async {
        let scenario = await makeScenario()
        await scenario.viewModel.reviewCleanUp()
        let found = scenario.viewModel.cleanUpSuggestions
        #expect(found.map(\.span) == [TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 31)])

        scenario.viewModel.removeSuggestion(found[0].id)
        #expect(scenario.viewModel.isRemoved(found[0]))
        #expect(!scenario.viewModel.isRemoved(found[1]))
        #expect(spans(scenario.viewModel) == [[0, 10], [12, 64]])

        // Kept: it plays again, and "Remove all" leaves it alone.
        scenario.viewModel.keepSuggestion(found[0].id)
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.pausesLeftToRemove == 1)
        scenario.viewModel.removeAllPauses()
        #expect(spans(scenario.viewModel) == [[0, 30], [31, 64]])

        // Each step is one undo.
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
        scenario.viewModel.undo()
        #expect(spans(scenario.viewModel) == [[0, 10], [12, 64]])
    }

    @Test func playingAPauseStartsJustBeforeIt() async {
        let scenario = await makeScenario()
        await scenario.viewModel.reviewCleanUp()
        let pause = scenario.viewModel.cleanUpSuggestions[1]
        scenario.viewModel.playSuggestion(pause.id)
        #expect(scenario.player.currentTime == 29)
        #expect(scenario.player.isPlaying)

        // Once removed, from where the edit picks up before it: 1 s earlier, minus the first cut.
        scenario.viewModel.removeAllPauses()
        scenario.viewModel.playSuggestion(pause.id)
        #expect(scenario.player.currentTime == 27)
    }

    @Test func pausesOutsideTheHandlesArentOffered() async {
        let scenario = await makeScenario()
        dragHandle(.end, to: 20, on: scenario.viewModel)
        await scenario.viewModel.reviewCleanUp()
        #expect(scenario.viewModel.cleanUpSuggestions.map(\.span) == [TimeSpan(start: 10, end: 12)])
    }

    // MARK: - Captions and look

    @Test func captionsComeFromTheScript() async {
        let scenario = await makeScenario()
        await scenario.viewModel.setShowsCaptions(true)
        #expect(scenario.viewModel.edit.showsCaptions)
        #expect(scenario.editor.captionScript == "Okay, real talk.")
        #expect(scenario.viewModel.edit.captions.count == 1)
    }

    @Test func pickingAStyleTurnsCaptionsOn() async {
        let scenario = await makeScenario()
        await scenario.viewModel.setCaptionStyle(.highlight)
        #expect(scenario.viewModel.edit.showsCaptions)
        #expect(scenario.viewModel.edit.captionStyle == .highlight)
    }

    @Test func autoAdjustsTheLook() async {
        let scenario = await makeScenario()
        scenario.viewModel.autoAdjust()
        #expect(scenario.viewModel.edit.exposure == 14)
        #expect(scenario.toast.message == "Auto-enhanced")
    }

    // MARK: - Leaving

    @Test func doneSavesTheEditTheNewLengthAndMarksTheTakeEdited() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.saveDraft()
        scenario.viewModel.done()
        let saved = scenario.takes.takes[0]
        #expect(saved.isEdited)
        #expect(saved.duration == 60)
        #expect(saved.edit?.timeline.trimStart == 4)
        #expect(scenario.toast.message == "Edits saved to Take 3")
        #expect(scenario.drafts.drafts.isEmpty)
        #expect(scenario.player.isStopped)
    }

    @Test func doneWithoutChangesLeavesTheTakeAlone() async {
        let scenario = await makeScenario()
        scenario.viewModel.done()
        #expect(!scenario.takes.takes[0].isEdited)
        #expect(scenario.takes.takes[0].edit == nil)
    }

    @Test func cancelWithChangesAsksFirst() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.cancel())
        let again = await makeScenario()
        dragHandle(.end, to: 30, on: again.viewModel)
        #expect(!again.viewModel.cancel())
        #expect(again.viewModel.confirmsDiscard)
        again.viewModel.discard()
        #expect(again.takes.takes[0].edit == nil)
        #expect(again.drafts.drafts.isEmpty)
    }

    @Test func anUnsavedEditIsPickedUpAgain() async {
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts)
        dragHandle(.start, to: 4, on: first.viewModel)
        first.player.seek(to: 10)
        first.viewModel.pauseAndKeepDraft()
        #expect(drafts.drafts.values.first?.playhead == 10)

        let second = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(second.viewModel.edit.timeline.trimStart == 4)
        #expect(second.viewModel.canUndo)
        #expect(second.player.currentTime == 10)
        #expect(second.toast.message == "Picked up where you left off")
    }

    @Test func editingAgainStartsFromTheSavedEdit() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.done()
        let again = await makeScenario(takes: scenario.takes)
        #expect(again.viewModel.edit.sourceDuration == 64)
        #expect(again.viewModel.edit.timeline.trimStart == 4)
        #expect(!again.viewModel.hasUnsavedChanges)
    }
}
