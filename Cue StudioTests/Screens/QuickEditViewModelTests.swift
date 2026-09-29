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
        #expect(scenario.viewModel.durationChange == "Original · 1:04")
        #expect(scenario.viewModel.timeLabel == "00:00.00 / 01:04.00")
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
        scenario.viewModel.cancel()
        #expect(scenario.drafts.drafts.isEmpty)
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
        #expect(scenario.viewModel.timeLabel == "00:07.00 / 00:07.00")
        #expect(scenario.viewModel.durationChange == "1:04 → 0:07")
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

    @Test func theStartHandleLeavesTheStartAndComesBackWithThePlayheadThere() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(scenario.player.currentTime == 0)
        viewModel.beginTrim(.start)
        viewModel.trim(.start, toSource: 5)
        #expect(viewModel.edit.timeline.trimStart == 5)
        #expect(viewModel.durationChange == "1:04 → 0:59")
        viewModel.trim(.start, toSource: 0)
        viewModel.endTrim()
        #expect(viewModel.edit.timeline.isWhole)
        // Out and back again changes nothing, so there is nothing to undo.
        #expect(!viewModel.canUndo)

        dragHandle(.start, to: 5, on: viewModel)
        dragHandle(.start, to: 0, on: viewModel)
        #expect(viewModel.edit.timeline.isWhole)
        #expect(viewModel.history.past.count == 2)
    }

    @Test func thePlayheadMovesWithoutTouchingTheHandles() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 5, on: viewModel)
        dragHandle(.end, to: 30, on: viewModel)
        for time in [0.0, 10, 100] {
            viewModel.scrub(to: time)
            viewModel.endScrub()
        }
        #expect(spans(viewModel) == [[5, 30]])
        // Held between the handles: 25 s is the end of the edit.
        #expect(scenario.player.currentTime == 25)
        #expect(viewModel.history.past.count == 2)
    }

    @Test func aHandleOnlyMovesWhileItsDragIsOn() async {
        let scenario = await makeScenario()
        scenario.viewModel.trim(.start, toSource: 10)
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    // MARK: - Cuts and trims

    /// Cut at 20 s of the 64 s take: [A | B], with B selected.
    private func cutAtTwenty(_ scenario: Scenario) {
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
    }

    @Test func aCutMakesTwoSections() async {
        // Case A.
        let scenario = await makeScenario()
        cutAtTwenty(scenario)
        #expect(spans(scenario.viewModel) == [[0, 20], [20, 64]])
        #expect(scenario.viewModel.edit.editedDuration == 64)
    }

    @Test func handlesTrimOnEitherSideOfACut() async {
        // Cases B and C: the start handle inside A, the end handle inside B.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        dragHandle(.start, to: 5, on: viewModel)
        dragHandle(.end, to: 50, on: viewModel)
        #expect(spans(viewModel) == [[5, 20], [20, 50]])
    }

    @Test func aHandleDraggedPastACutKeepsTrimming() async {
        // Case D: the cut is no barrier; A leaves the edit and the division goes with it.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        dragHandle(.start, to: 30, on: viewModel)
        #expect(spans(viewModel) == [[30, 64]])
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(viewModel.selectedSegmentIndex == nil)
        #expect(viewModel.durationChange == "1:04 → 0:34")
        dragHandle(.end, to: 40, on: viewModel)
        #expect(spans(viewModel) == [[30, 40]])
    }

    @Test func theEndHandleCrossesACutToo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        dragHandle(.end, to: 12, on: viewModel)
        #expect(spans(viewModel) == [[0, 12]])
    }

    @Test func goingBackBeforeLettingGoBringsTheCutBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        let ids = viewModel.edit.timeline.segments.map(\.id)
        viewModel.beginTrim(.start)
        viewModel.trim(.start, toSource: 30)
        #expect(spans(viewModel) == [[30, 64]])
        // The strip keeps drawing the timeline the drag began with.
        #expect(viewModel.trimOrigin?.segments.map(\.id) == ids)
        viewModel.trim(.start, toSource: 10)
        viewModel.endTrim()
        #expect(spans(viewModel) == [[10, 20], [20, 64]])
        #expect(viewModel.edit.timeline.segments.map(\.id) == ids)
        #expect(viewModel.trimOrigin == nil)
        #expect(viewModel.history.past.count == 2)
    }

    @Test func deletingTheSecondSectionLeavesOnlyTheFirst() async {
        // Case E: the cut selected B; Delete leaves A alone, with no cut left behind.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        viewModel.removeSelection()
        #expect(spans(viewModel) == [[0, 20]])
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(viewModel.edit.timeline.tail == TimeSpan(start: 20, end: 64))
    }

    @Test func cutTrimAndCutAgain() async {
        // Case F.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        dragHandle(.start, to: 5, on: viewModel)
        // 30 s into the edit is 35 s into the recording.
        scenario.player.seek(to: 30)
        viewModel.cut()
        #expect(spans(viewModel) == [[5, 20], [20, 35], [35, 64]])
        dragHandle(.start, to: 25, on: viewModel)
        #expect(spans(viewModel) == [[25, 35], [35, 64]])
    }

    @Test func aTrimAcrossSeveralCutsLeavesNoGhosts() async {
        // Case G: [A][B][C][D], the start handle dragged into C, then the end handle into C.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        for cut in [16.0, 32, 48] {
            scenario.player.seek(to: cut)
            viewModel.cut()
        }
        #expect(viewModel.edit.timeline.segments.count == 4)
        dragHandle(.start, to: 40, on: viewModel)
        #expect(spans(viewModel) == [[40, 48], [48, 64]])
        dragHandle(.end, to: 44, on: viewModel)
        #expect(spans(viewModel) == [[40, 44]])
        #expect(viewModel.edit.editedDuration == 4)
    }

    @Test func undoAndRedoATrimAcrossACut() async {
        // Case H: the cut, and the sections it made, come back with undo.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        let cut = viewModel.edit.timeline
        dragHandle(.start, to: 30, on: viewModel)
        let trimmed = viewModel.edit.timeline
        viewModel.undo()
        #expect(viewModel.edit.timeline == cut)
        viewModel.redo()
        #expect(viewModel.edit.timeline == trimmed)
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
    }

    // MARK: - Transitions

    @Test func aCutIsAHardCutUntilATransitionIsPicked() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .hardCut)
        #expect(viewModel.selectedTransition == nil)

        viewModel.tapJoin(1)
        #expect(viewModel.selectedJoinIndex == 1)
        #expect(viewModel.selectedSegmentIndex == nil)
        #expect(viewModel.selectedTransition == .hardCut)
        #expect(viewModel.trimHint == "Cut at 00:20.00 · None keeps it a hard cut")

        viewModel.setTransition(.fade)
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .fade)
        #expect(scenario.player.shown.last?.timeline.transition(atJoin: 1) == .fade)
        // A moment before the cut, so Play shows it.
        #expect(scenario.player.currentTime == 20 - QuickEditViewModel.transitionLeadIn)

        viewModel.undo()
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .hardCut)
        viewModel.redo()
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .fade)

        viewModel.closeTransitions()
        #expect(viewModel.selectedTransition == nil)
        viewModel.done()
        #expect(scenario.takes.takes[0].edit?.timeline.transition(atJoin: 1) == .fade)
    }

    @Test func aDissolveOverACutThatRemovedNothingSaysSo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        viewModel.tapJoin(1)
        viewModel.setTransition(.dissolve)
        #expect(viewModel.trimHint == "Nothing was cut out here, so Dissolve won't show")
    }

    @Test func aCutOrASectionIsSelectedNeverBoth() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        viewModel.tapJoin(1)
        viewModel.tapTimeline(onPiece: 0)
        #expect(viewModel.selectedJoinIndex == nil)
        #expect(viewModel.selectedSegmentIndex == 0)
        viewModel.tapJoin(1)
        #expect(viewModel.selectedSegmentIndex == nil)
        // Tapping the same cut again lets go of it; the first section has no cut before it.
        viewModel.tapJoin(1)
        #expect(viewModel.selectedJoinIndex == nil)
        viewModel.tapJoin(0)
        #expect(viewModel.selectedJoinIndex == nil)
        // Nothing to pick while the red range shows.
        viewModel.startRemovingPart()
        viewModel.tapJoin(1)
        #expect(viewModel.selectedJoinIndex == nil)
    }

    @Test func aTrimThatTakesTheCutTakesItsTransition() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        viewModel.tapJoin(1)
        viewModel.setTransition(.dissolve)
        dragHandle(.start, to: 30, on: viewModel)
        #expect(viewModel.selectedTransition == nil)
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(viewModel.edit.timeline.segments[0].transitionIn == .hardCut)
        // Undo brings back the cut with its dissolve.
        viewModel.undo()
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .dissolve)
    }

    // MARK: - Frames

    @Test func readsTheFrameRateFromTheFile() async {
        let editor = FakeTakeEditor()
        editor.nominalFrameRate = 60
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.frameRate == 60)
        #expect(abs(scenario.viewModel.frameSnapped(edited: 10.44) - 626.0 / 60) < 0.000_1)
    }

    @Test func withoutARateInTheFileItUsesTheTakes() async {
        let editor = FakeTakeEditor()
        editor.nominalFrameRate = nil
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.frameRate == 30)
        #expect(abs(scenario.viewModel.frameSnapped(edited: 10.44) - 313.0 / 30) < 0.000_1)
    }

    // MARK: - Remove part

    @Test func removePartTakesTheRedRangeOut() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.startRemovingPart()
        #expect(scenario.viewModel.removalRange == 19...21)
        #expect(scenario.viewModel.removalLengthLabel == "00:02.00")
        #expect(scenario.viewModel.trimHint == "Drag the red edges over the part you want gone")
        scenario.viewModel.removePart()
        #expect(spans(scenario.viewModel) == [[0, 19], [21, 64]])
        #expect(scenario.viewModel.removalRange == nil)
        #expect(scenario.player.currentTime == 19)
        #expect(scenario.toast.message == "Removed 00:02.00")
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    @Test func theRedRangeIsThePartThePlayerReviews() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.startRemovingPart()
        #expect(scenario.player.reviewedPart == 19...21)
        scenario.viewModel.moveRemovalEdge(.end, toEdited: 30)
        #expect(scenario.player.reviewedPart == 19...30)
        scenario.viewModel.cancelRemovingPart()
        #expect(scenario.player.reviewedPart == nil)
        scenario.viewModel.startRemovingPart()
        scenario.viewModel.removePart()
        #expect(scenario.player.reviewedPart == nil)
    }

    @Test func theRedEdgesMoveAndNeverCross() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.startRemovingPart()
        scenario.viewModel.moveRemovalEdge(.end, toEdited: 30)
        #expect(scenario.viewModel.removalRange == 19...30)
        #expect(scenario.player.currentTime == 30)
        scenario.viewModel.moveRemovalEdge(.start, toEdited: 40)
        #expect(scenario.viewModel.removalRange?.upperBound == 30)
        #expect(abs((scenario.viewModel.removalRange?.lowerBound ?? 0) - 29.8) < 0.000_1)
        scenario.viewModel.moveRemovalEdge(.end, toEdited: 100)
        #expect(scenario.viewModel.removalRange?.upperBound == 64)
    }

    @Test func aPartAcrossACutTakesFromBothSides() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        scenario.viewModel.startRemovingPart()
        scenario.viewModel.removePart()
        #expect(spans(scenario.viewModel) == [[0, 19], [21, 64]])
    }

    @Test func cancellingOrChangingToolDropsTheRange() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.startRemovingPart()
        scenario.viewModel.cancelRemovingPart()
        #expect(scenario.viewModel.removalRange == nil)
        scenario.viewModel.startRemovingPart()
        scenario.viewModel.tool = .audio
        #expect(scenario.viewModel.removalRange == nil)
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    // MARK: - Cut and delete

    @Test func cutSplitsAtThePlayheadAndSelectsTheSecondHalf() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        #expect(spans(scenario.viewModel) == [[0, 20], [20, 64]])
        #expect(scenario.viewModel.edit.editedDuration == 64)
        #expect(scenario.viewModel.selectedSegmentIndex == 1)
        #expect(scenario.viewModel.canDeleteSelection)
        #expect(scenario.toast.message == "Cut at 00:20.00 — tap a side, then Delete")
        #expect(scenario.viewModel.trimHint == "Section 2 selected · Delete removes it")
    }

    @Test func cuttingAtAnEdgeExplains() async {
        let scenario = await makeScenario()
        scenario.viewModel.cut()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move the playhead away from the edge")
    }

    @Test func cuttingAtTheEndExplainsToo() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 64)
        scenario.viewModel.cut()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move the playhead away from the edge")
        #expect(!scenario.viewModel.canUndo)
    }

    @Test func deletingTheSelectedSection() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        scenario.viewModel.removeSelection()
        #expect(spans(scenario.viewModel) == [[0, 20]])
        #expect(scenario.viewModel.durationChange == "1:04 → 0:20")
        #expect(scenario.viewModel.selectedSegmentID == nil)
        #expect(scenario.toast.message == "Section deleted")
        #expect(scenario.player.shown.last?.keptSpans == [TimeSpan(start: 0, end: 20)])
    }

    @Test func tappingASelectedSectionLetsItGo() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.cut()
        scenario.viewModel.tapTimeline(onPiece: 1)
        #expect(scenario.viewModel.selectedSegmentID == nil)
        scenario.viewModel.tapTimeline(onPiece: 0)
        #expect(scenario.viewModel.selectedSegmentIndex == 0)
    }

    @Test func deleteNeedsASelectionAndThereIsNoneWithOneSection() async {
        let scenario = await makeScenario()
        scenario.viewModel.removeSelection()
        #expect(scenario.toast.message == "Tap a section first")
        scenario.viewModel.tapTimeline(onPiece: 0)
        #expect(scenario.viewModel.selectedSegmentID == nil)
        #expect(!scenario.viewModel.canDeleteSelection)
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    @Test func deletingBAndDLeavesAAndC() async {
        let scenario = await makeScenario()
        for cut in [16.0, 32, 48] {
            scenario.player.seek(to: cut)
            scenario.viewModel.cut()
        }
        // The last cut left D selected.
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

    @Test func deletingAnEarlierSectionKeepsThePlayheadOnItsFrame() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 10)
        scenario.viewModel.cut()
        scenario.player.seek(to: 30)
        scenario.viewModel.tapTimeline(onPiece: 0)
        scenario.viewModel.removeSelection()
        #expect(scenario.player.currentTime == 20)
    }

    // MARK: - Undo

    @Test func undoAndRedoWalkThroughTrimCutAndDelete() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 4, on: viewModel)
        scenario.player.seek(to: 16)
        viewModel.cut()
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

    @Test func trimSplitDeleteUndoRedoAndWhatIsSavedAllShareOneTimeline() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 5, on: viewModel)
        dragHandle(.end, to: 30, on: viewModel)
        #expect(spans(viewModel) == [[5, 30]])

        // 7 s into the edit is 12 s into the recording.
        scenario.player.seek(to: 7)
        viewModel.cut()
        #expect(spans(viewModel) == [[5, 12], [12, 30]])
        viewModel.tapTimeline(onPiece: 0)
        viewModel.removeSelection()
        #expect(spans(viewModel) == [[12, 30]])
        #expect(viewModel.durationChange == "1:04 → 0:18")
        #expect(scenario.player.shown.last?.keptSpans == [TimeSpan(start: 12, end: 30)])

        viewModel.undo()
        #expect(spans(viewModel) == [[5, 12], [12, 30]])
        viewModel.undo()
        #expect(spans(viewModel) == [[5, 30]])
        viewModel.undo()
        #expect(spans(viewModel) == [[5, 64]])
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)

        for _ in 0..<4 { viewModel.redo() }
        #expect(spans(viewModel) == [[12, 30]])
        #expect(!viewModel.canRedo)

        // What Done saves is what the export plays.
        viewModel.done()
        let saved = scenario.takes.takes[0]
        #expect(saved.edit?.keptSpans == [TimeSpan(start: 12, end: 30)])
        #expect(saved.duration == 18)
    }

    @Test func undoLeavesTheLightAndSoundAlone() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.edit.exposure = 30
        scenario.viewModel.edit.volume = 0.5
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.edit.exposure == 30)
        #expect(scenario.viewModel.edit.volume == 0.5)
    }

    /// A filter is set by Style too, so it's an undo step of its own.
    @Test func aFilterIsItsOwnUndoStep() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.setFilter(.mono)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.filter == .original)
        #expect(scenario.viewModel.edit.timeline.trimStart == 4)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    // MARK: - Clean Up

    @Test func cleanUpFindsSuggestionsAndRemovesNothing() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.analysis == .idle)
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.analysis == .done)
        #expect(scenario.editor.cleanUpScript == "Okay, real talk.")
        #expect(scenario.viewModel.cleanUpSuggestions.map(\.span) == [TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 31)])
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.reviewTitle == "2 to review")
        #expect(scenario.viewModel.removeAllLabel == "Remove all · 2")
        #expect(scenario.viewModel.cleanUpBadge == 2)
    }

    @Test func cleanUpListensOnce() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        scenario.editor.silences = []
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.cleanUpSuggestions.count == 2)
    }

    @Test func aTakeThatCantBeHeardSaysSo() async {
        let editor = FakeTakeEditor()
        editor.cleanUpFails = true
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.analysis == .failed)
        #expect(scenario.toast.message == "Couldn't listen to this take")
        #expect(scenario.viewModel.cleanUpSuggestions.isEmpty)
    }

    @Test func nothingFoundIsAllClean() async {
        let editor = FakeTakeEditor()
        editor.silences = []
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.analysis == .done)
        #expect(scenario.viewModel.reviewTitle == "All clean")
        #expect(scenario.viewModel.removeAllLabel == "Done")
        #expect(scenario.viewModel.cleanUpBadge == nil)
    }

    @Test func removingASuggestionIsOneUndoStepWithItsDecision() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        let first = scenario.viewModel.cleanUpSuggestions[0]
        scenario.viewModel.removeSuggestion(first.id)
        #expect(spans(scenario.viewModel) == [[0, 10], [12, 64]])
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .removed)
        #expect(scenario.toast.message == "Pause removed")
        #expect(scenario.viewModel.reviewTitle == "1 to review")

        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .pending)
        scenario.viewModel.redo()
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .removed)
    }

    @Test func keptSuggestionsStayAndCanBeReviewedAgain() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        let first = scenario.viewModel.cleanUpSuggestions[0]
        scenario.viewModel.keepSuggestion(first.id)
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .kept)
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.removeAllLabel == "Remove all · 1")
        scenario.viewModel.reviewAgain(first.id)
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .pending)
        scenario.viewModel.keepSuggestion(first.id)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .pending)
    }

    @Test func aRemovedSuggestionComesBackWithUndoOnly() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        let first = scenario.viewModel.cleanUpSuggestions[0]
        scenario.viewModel.removeSuggestion(first.id)
        scenario.viewModel.reviewAgain(first.id)
        #expect(scenario.toast.message == "Use Undo to bring it back")
        #expect(scenario.viewModel.cleanUpSuggestions[0].status == .removed)
    }

    @Test func removeAllTakesOnlyWhatCleanUpIsSureAbout() async {
        let editor = FakeTakeEditor()
        // A 2.3 s pause and a 0.6 s one (the cut keeps 0.15 s each side).
        editor.silences = [TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 30.3)]
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.analyzeIfNeeded()
        // The short one hides under "Ignore pauses under 0.7s".
        #expect(scenario.viewModel.cleanUpSuggestions.count == 1)
        #expect(scenario.viewModel.ignoredPausesLabel == "1 short pause kept")
        scenario.viewModel.lowerPauseThreshold()
        #expect(scenario.viewModel.pauseThresholdLabel == "\(TestData.decimal("0.6"))s")
        #expect(scenario.viewModel.cleanUpSuggestions.count == 2)
        #expect(scenario.viewModel.ignoredPausesLabel == "natural pauses stay")

        scenario.viewModel.removeAllSureSuggestions()
        #expect(spans(scenario.viewModel) == [[0, 10], [12, 64]])
        #expect(scenario.toast.message == "Removed 1 · 1 left to review")
        #expect(scenario.viewModel.pendingSuggestions.map(\.span.start) == [30])
        #expect(scenario.viewModel.removeAllLabel == "Done")
    }

    @Test func tappingASuggestionMovesThePlayheadThere() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        let found = scenario.viewModel.cleanUpSuggestions
        scenario.viewModel.togglePlayback()
        scenario.viewModel.seek(toSuggestion: found[1].id)
        #expect(scenario.player.currentTime == 30)
        #expect(!scenario.player.isPlaying)
        scenario.viewModel.removeSuggestion(found[0].id)
        scenario.viewModel.seek(toSuggestion: found[1].id)
        #expect(scenario.player.currentTime == 28)
        scenario.viewModel.seek(toSuggestion: found[0].id)
        #expect(scenario.toast.message == "Already removed")
    }

    @Test func suggestionsOutsideTheHandlesArentListed() async {
        let scenario = await makeScenario()
        dragHandle(.end, to: 20, on: scenario.viewModel)
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.cleanUpSuggestions.map(\.span) == [TimeSpan(start: 10, end: 12)])
    }

    @Test func undoingAnEarlierStepKeepsWhatCleanUpFound() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 2, on: scenario.viewModel)
        await scenario.viewModel.analyzeIfNeeded()
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.cleanUpSuggestions.count == 2)
    }

    @Test func fillersAndRetakesComeFromTheTranscript() async {
        let editor = FakeTakeEditor()
        editor.silences = []
        editor.transcript = TakeTranscript(
            words: [("So", 0.0), ("um,", 0.25), ("today", 0.5)].map { TimedWord(text: $0.0, start: $0.1, end: $0.1 + 0.25) },
            languageCode: "en"
        )
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.cleanUpSuggestions.map(\.kind) == [.filler])
        #expect(scenario.viewModel.cleanUpSuggestions.first?.title == "“um,”")
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

    @Test func cancelKeepsADraftThatEditPicksUp() async {
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts)
        dragHandle(.end, to: 30, on: first.viewModel)
        first.viewModel.cancel()
        #expect(first.takes.takes[0].edit == nil)
        #expect(drafts.drafts.count == 1)
        #expect(first.toast.message == "Draft kept — tap Edit to continue")
        #expect(first.player.isStopped)

        let second = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(second.viewModel.edit.timeline.trimEnd == 30)
        #expect(second.viewModel.canUndo)
        #expect(second.toast.message == "Draft restored")
    }

    @Test func cancelWithoutChangesLeavesNoDraft() async {
        let scenario = await makeScenario()
        scenario.viewModel.cancel()
        #expect(scenario.drafts.drafts.isEmpty)
        #expect(scenario.player.isStopped)
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
        #expect(second.toast.message == "Draft restored")
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
