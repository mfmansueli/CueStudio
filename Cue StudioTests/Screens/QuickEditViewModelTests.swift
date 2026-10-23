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
        takes: TakeLibraryService? = nil,
        repository: FakeTakeRepository? = nil
    ) async -> Scenario {
        var take = TestData.take(scriptID: script?.id, number: 3)
        take.duration = 64
        let takes = takes ?? {
            let service = TakeLibraryService(repository: repository.map { $0.takes = [take]; return $0 } ?? FakeTakeRepository(takes: [take]))
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

    /// Drags an outer handle (the first clip's start, the last clip's end) to `time` of the recording, as one gesture.
    private func dragHandle(_ handle: TrimHandle, to time: TimeInterval, on viewModel: QuickEditViewModel) {
        let segments = viewModel.edit.timeline.segments
        guard let clip = handle == .start ? segments.first : segments.last else { return }
        viewModel.beginTimelineHandle(.clip(clip.id, handle), snapTimes: [])
        viewModel.moveTimelineHandle(by: (time - (handle == .start ? clip.sourceStart : clip.sourceEnd)) / clip.speed)
        viewModel.endTimelineHandle()
    }

    // MARK: - Opening

    @Test func startsFromTheWholeTake() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.source == .ready)
        #expect(scenario.viewModel.timeLabel == "00:00.0 / 01:04.0")
        #expect(scenario.viewModel.edit.aspect == .portrait)
        #expect(scenario.player.shown.last == scenario.viewModel.edit)
    }

    @Test func aMissingRecordingCantBeEdited() async {
        let editor = FakeTakeEditor()
        editor.duration = nil
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.source == .unavailable)
        #expect(!scenario.viewModel.isReady)
        scenario.viewModel.splitClip()
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

    @Test func aHandleDragIsOneUndoStepAndHandlesNeverCross() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.beginTimelineHandle(.clip(viewModel.edit.timeline.segments[0].id, .start), snapTimes: [])
        #expect(!viewModel.canUndo)
        for offset in [5.0, 20, 80] { viewModel.moveTimelineHandle(by: offset) }
        viewModel.endTimelineHandle()
        #expect(viewModel.handleDrag == nil)
        #expect(viewModel.edit.timeline.trimStart < viewModel.edit.timeline.trimEnd)
        #expect(viewModel.history.past.count == 1)
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
    }

    @Test func thePlayheadMovesWithoutTouchingTheHandles() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 5, on: viewModel)
        dragHandle(.end, to: 30, on: viewModel)
        for time in [0.0, 10, 100] {
            viewModel.scrubTimeline(to: time)
            viewModel.endTimelineScrub()
        }
        #expect(spans(viewModel) == [[5, 30]])
        // Held between the handles: 25 s is the end of the edit.
        #expect(scenario.player.currentTime == 25)
        #expect(viewModel.history.past.count == 2)
    }

    @Test func aHandleOnlyMovesWhileItsDragIsOn() async {
        let scenario = await makeScenario()
        scenario.viewModel.moveTimelineHandle(by: 10)
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    // MARK: - Cuts and trims

    /// Cut at 20 s of the 64 s take: [A | B], with B selected.
    private func cutAtTwenty(_ scenario: Scenario) {
        scenario.player.seek(to: 20)
        scenario.viewModel.splitClip()
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

    @Test func deletingTheSecondSectionLeavesOnlyTheFirst() async {
        // Case E: the cut selected B; Delete leaves A alone, with no cut left behind.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        viewModel.perform(.deleteClip)
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
        viewModel.splitClip()
        #expect(spans(viewModel) == [[5, 20], [20, 35], [35, 64]])
    }

    @Test func undoAndRedoATrimAfterACut() async {
        // Case H: the cut, and the sections it made, come back with undo.
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        let cut = viewModel.edit.timeline
        dragHandle(.start, to: 10, on: viewModel)
        let trimmed = viewModel.edit.timeline
        #expect(spans(viewModel) == [[10, 20], [20, 64]])
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

        viewModel.tapTimeline(.join(viewModel.edit.timeline.segments[1].id))
        #expect(viewModel.selectedJoinIndex == 1)
        #expect(viewModel.panel == .transition)
        #expect(viewModel.selectedSegmentIndex == nil)
        #expect(viewModel.selectedTransition == .hardCut)
        #expect(viewModel.transitionNote == nil)

        viewModel.setTransition(.fade)
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .fade)
        #expect(scenario.player.shown.last?.timeline.transition(atJoin: 1) == .fade)
        // A moment before the cut, so Play shows it.
        #expect(scenario.player.currentTime == 20 - QuickEditViewModel.transitionLeadIn)

        viewModel.undo()
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .hardCut)
        viewModel.redo()
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .fade)

        // Closing the transitions lets go of the cut.
        viewModel.panel = nil
        #expect(viewModel.selectedTransition == nil)
        viewModel.done()
        #expect(scenario.takes.takes[0].edit?.timeline.transition(atJoin: 1) == .fade)
    }

    @Test func aDissolveOverACutThatRemovedNothingSaysSo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        viewModel.pickJoin(viewModel.edit.timeline.segments[1].id)
        viewModel.setTransition(.dissolve)
        #expect(viewModel.transitionNote == "Nothing was cut out here, so Dissolve won't show")
    }

    @Test func aCutOrASectionIsSelectedNeverBoth() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        cutAtTwenty(scenario)
        let segments = viewModel.edit.timeline.segments
        viewModel.tapTimeline(.join(segments[1].id))
        viewModel.tapTimeline(.clip(segments[0].id))
        #expect(viewModel.selectedJoinIndex == nil)
        #expect(viewModel.selectedSegmentIndex == 0)
        viewModel.tapTimeline(.join(segments[1].id))
        #expect(viewModel.selectedSegmentIndex == nil)
        // Tapping the same cut again lets go of it.
        viewModel.tapTimeline(.join(segments[1].id))
        #expect(viewModel.selectedJoinIndex == nil)
    }

    // MARK: - Frames

    @Test func readsTheFrameRateFromTheFile() async {
        let editor = FakeTakeEditor()
        editor.nominalFrameRate = 60
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.frameRate == 60)
    }

    @Test func withoutARateInTheFileItUsesTheTakes() async {
        let editor = FakeTakeEditor()
        editor.nominalFrameRate = nil
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.frameRate == 30)
    }

    // MARK: - Split and delete

    @Test func splitCutsAtThePlayheadAndPicksTheSecondHalf() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.splitClip()
        #expect(spans(scenario.viewModel) == [[0, 20], [20, 64]])
        #expect(scenario.viewModel.edit.editedDuration == 64)
        #expect(scenario.viewModel.selectedSegmentIndex == 1)
        #expect(scenario.toast.message == "Split at \(DurationText.editor(20))")
    }

    @Test func splittingAtAnEdgeExplains() async {
        let scenario = await makeScenario()
        scenario.viewModel.splitClip()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move playhead onto the clip")
    }

    @Test func splittingAtTheEndExplainsToo() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 64)
        scenario.viewModel.splitClip()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move playhead onto the clip")
        #expect(!scenario.viewModel.canUndo)
    }

    @Test func deletingThePickedClip() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.splitClip()
        scenario.viewModel.perform(.deleteClip)
        #expect(spans(scenario.viewModel) == [[0, 20]])
        #expect(scenario.viewModel.edit.editedDuration == 20)
        #expect(scenario.viewModel.selectedSegmentID == nil)
        #expect(scenario.toast.message == "Clip 2 deleted")
        #expect(scenario.toast.action?.title == "Undo")
        #expect(scenario.player.shown.last?.keptSpans == [TimeSpan(start: 0, end: 20)])
    }

    @Test func theLastClipStays() async {
        let scenario = await makeScenario()
        scenario.viewModel.deleteClip(scenario.viewModel.edit.timeline.segments[0].id)
        #expect(scenario.toast.message == "Keep at least one clip")
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(!scenario.viewModel.canUndo)
    }

    @Test func deletingBAndDLeavesAAndC() async {
        let scenario = await makeScenario()
        for cut in [16.0, 32, 48] {
            scenario.player.seek(to: cut)
            scenario.viewModel.splitClip()
        }
        // The last split left D picked.
        scenario.viewModel.perform(.deleteClip)
        scenario.viewModel.deleteClip(scenario.viewModel.edit.timeline.segments[1].id)
        #expect(spans(scenario.viewModel) == [[0, 16], [32, 48]])
        #expect(scenario.viewModel.edit.editedDuration == 32)
    }

    @Test func theSelectionIsNotThePlayhead() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.splitClip()
        scenario.viewModel.tapTimeline(.clip(scenario.viewModel.edit.timeline.segments[0].id))
        scenario.viewModel.scrubTimeline(to: 40)
        scenario.viewModel.endTimelineScrub()
        #expect(scenario.viewModel.selectedSegmentIndex == 0)
        scenario.viewModel.tapTimeline(nil)
        #expect(scenario.viewModel.selectedSegmentID == nil)
    }

    @Test func scrubbingPausesAndMovesThePlayhead() async {
        let scenario = await makeScenario()
        scenario.viewModel.togglePlayback()
        #expect(scenario.player.isPlaying)
        scenario.viewModel.scrubTimeline(to: 6.18)
        #expect(!scenario.player.isPlaying)
        #expect(scenario.player.isScrubbing)
        #expect(scenario.player.currentTime == 6.18)
        scenario.viewModel.endTimelineScrub()
        #expect(!scenario.player.isScrubbing)
        #expect(!scenario.player.isPlaying)
    }

    @Test func deletingAnEarlierClipKeepsThePlayheadOnItsFrame() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 10)
        scenario.viewModel.splitClip()
        scenario.player.seek(to: 30)
        scenario.viewModel.deleteClip(scenario.viewModel.edit.timeline.segments[0].id)
        #expect(scenario.player.currentTime == 20)
    }

    // MARK: - Undo

    @Test func undoAndRedoWalkThroughTrimCutAndDelete() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 4, on: viewModel)
        scenario.player.seek(to: 16)
        viewModel.splitClip()
        viewModel.perform(.deleteClip)
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
        viewModel.splitClip()
        #expect(spans(viewModel) == [[5, 12], [12, 30]])
        viewModel.tapTimeline(.clip(viewModel.edit.timeline.segments[0].id))
        viewModel.perform(.deleteClip)
        #expect(spans(viewModel) == [[12, 30]])
        #expect(viewModel.edit.editedDuration == 18)
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

    /// The v10 editor undoes everything: the light and the sound too.
    @Test func undoTakesBackTheLightAndTheSound() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.setAdjustment(.exposure, 30)
        scenario.viewModel.setVoiceEnhancement(.strong)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.exposure == 30)
        #expect(scenario.viewModel.edit.voiceEnhancement != .strong)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.exposure == 0)
        #expect(scenario.viewModel.edit.timeline.trimStart == 4)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    /// A filter is set by Style too, so it's an undo step of its own.
    @Test func aFilterIsItsOwnUndoStep() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.pickFilter(.mono)
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
        #expect(scenario.viewModel.pauseCandidates.isEmpty && scenario.viewModel.wordCandidates.isEmpty)
        #expect(scenario.viewModel.cleanUpApplyLabel == "Nothing selected")
    }

    @Test func tappingASuggestionMovesThePlayheadThere() async throws {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        let found = scenario.viewModel.cleanUpSuggestions
        scenario.viewModel.togglePlayback()
        scenario.viewModel.tapCleanUpCard(found[1].id)
        let start = try #require(scenario.viewModel.edit.timeline.editedSpan(of: found[1])?.start)
        #expect(abs(scenario.player.currentTime - (start - 0.4)) < 0.000_1)
        #expect(!scenario.player.isPlaying)
        // The tap also switches its mark.
        #expect(!scenario.viewModel.isMarked(found[1]))
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
        scenario.viewModel.makeCaptions()
        await scenario.viewModel.captionTask?.value
        #expect(scenario.viewModel.edit.showsCaptions)
        #expect(scenario.editor.captionScript == "Okay, real talk.")
        #expect(scenario.viewModel.edit.captions.count == 1)
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
        #expect(scenario.toast.message == "Edits saved to this take")
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
        #expect(first.toast.message == "Draft saved")
        #expect(first.player.isStopped)

        let second = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(second.viewModel.edit.timeline.trimEnd == 30)
        #expect(second.viewModel.canUndo)
        #expect(second.toast.message == "Draft restored")
    }

    @Test func doneThatCantSaveOnTheTakeKeepsADraftAndSaysSo() async {
        let repository = FakeTakeRepository()
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts, repository: repository)
        repository.failsToSave = true
        dragHandle(.start, to: 4, on: first.viewModel)
        first.viewModel.done()
        #expect(first.toast.message == "Couldn't save the edits · Kept as a draft")
        #expect(drafts.drafts.values.first?.edit.timeline.trimStart == 4)
        #expect(repository.takes[0].edit == nil)
        #expect(first.player.isStopped)

        // Next launch: the take on disk is as it was, and Edit opens the draft.
        repository.failsToSave = false
        let relaunched = TakeLibraryService(repository: repository)
        relaunched.load()
        #expect(relaunched.takes[0].edit == nil)
        let second = await makeScenario(drafts: drafts, takes: relaunched)
        #expect(second.viewModel.edit.timeline.trimStart == 4)
        #expect(second.toast.message == "Draft restored")
    }

    @Test func doneThatCantSaveAnywhereSaysNothingWasSaved() async {
        let repository = FakeTakeRepository()
        let drafts = FakeDraftStore()
        let scenario = await makeScenario(drafts: drafts, repository: repository)
        repository.failsToSave = true
        drafts.failsToSave = true
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.done()
        #expect(scenario.toast.message == "Couldn't save the edits · Free up space on this iPhone")
    }

    @Test func cancelThatCantWriteTheDraftNeverSaysDraftSaved() async {
        let drafts = FakeDraftStore()
        drafts.failsToSave = true
        let scenario = await makeScenario(drafts: drafts)
        dragHandle(.end, to: 30, on: scenario.viewModel)
        scenario.viewModel.cancel()
        #expect(drafts.drafts.isEmpty)
        #expect(scenario.toast.message == "Couldn't save the edits · Free up space on this iPhone")

        let notYet = await makeScenario(drafts: drafts)
        notYet.viewModel.finish(.notYet)
        #expect(notYet.toast.message == "Couldn't save the edits · Free up space on this iPhone")
    }

    // MARK: - Done asks "Is it ready to post?"

    @Test func doneOpensTheQuestionAndLeavesTheEditAsItWas() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.panel = .adjust
        scenario.viewModel.askIfReadyToPost()
        #expect(scenario.viewModel.sheet == .done)
        #expect(scenario.viewModel.panel == nil)
        // Nothing is saved on the take until it is answered.
        #expect(!scenario.takes.takes[0].isEdited)
    }

    @Test(arguments: [EditorOutcome.share, .download, .ready])
    func shareDownloadAndReadyLaterSaveTheEditAndDropTheDraft(_ outcome: EditorOutcome) async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 4, on: scenario.viewModel)
        scenario.viewModel.saveDraft()
        scenario.viewModel.askIfReadyToPost()
        scenario.viewModel.finish(outcome)
        #expect(scenario.viewModel.sheet == nil)
        #expect(scenario.takes.takes[0].isEdited)
        #expect(scenario.takes.takes[0].edit?.timeline.trimStart == 4)
        #expect(scenario.drafts.drafts.isEmpty)
        #expect(scenario.player.isStopped)
    }

    @Test func notYetKeepsTheDraftEvenWithoutChangesAndDoesNotTouchTheTake() async {
        let scenario = await makeScenario()
        scenario.viewModel.finish(.notYet)
        // The video stays in edit: a draft is what says so.
        #expect(scenario.drafts.drafts.count == 1)
        #expect(scenario.takes.takes[0].edit == nil)
        #expect(!scenario.takes.takes[0].isEdited)
        #expect(scenario.player.isStopped)

        let changed = await makeScenario()
        dragHandle(.end, to: 30, on: changed.viewModel)
        changed.viewModel.finish(.notYet)
        #expect(changed.drafts.drafts.count == 1)
        #expect(changed.drafts.drafts.values.first?.edit.timeline.trimEnd == 30)
        #expect(!changed.takes.takes[0].isEdited)
    }

    @Test func backKeepsADraftOnlyWhenSomethingChanged() async {
        let untouched = await makeScenario()
        untouched.viewModel.finish(.back)
        #expect(untouched.drafts.drafts.isEmpty)

        let changed = await makeScenario()
        dragHandle(.end, to: 30, on: changed.viewModel)
        changed.viewModel.finish(.back)
        #expect(changed.drafts.drafts.count == 1)
        #expect(!changed.takes.takes[0].isEdited)
    }

    @Test func theTopBarSaysWhetherAnythingChanged() async {
        let scenario = await makeScenario()
        #expect(!scenario.viewModel.hasUnsavedChanges)
        dragHandle(.start, to: 4, on: scenario.viewModel)
        #expect(scenario.viewModel.hasUnsavedChanges)
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
