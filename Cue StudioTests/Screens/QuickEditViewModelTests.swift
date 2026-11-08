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
        repository: FakeTakeRepository? = nil,
        prepares: Bool = true
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
        if prepares { await viewModel.prepare() }
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
        scenario.viewModel.clips.splitClip()
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
        #expect(viewModel.document.history.past.count == 1)
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
        #expect(viewModel.document.history.past.count == 2)
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
        scenario.viewModel.clips.splitClip()
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
        viewModel.clips.splitClip()
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
        #expect(viewModel.clips.transitionNote == nil)

        viewModel.clips.setTransition(.fade)
        #expect(viewModel.edit.timeline.transition(atJoin: 1) == .fade)
        #expect(scenario.player.shown.last?.timeline.transition(atJoin: 1) == .fade)
        // A moment before the cut, so Play shows it.
        #expect(scenario.player.currentTime == 20 - ClipsViewModel.transitionLeadIn)

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
        viewModel.clips.setTransition(.dissolve)
        #expect(viewModel.clips.transitionNote == "Nothing was cut out here, so Dissolve won't show")
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
        scenario.viewModel.clips.splitClip()
        #expect(spans(scenario.viewModel) == [[0, 20], [20, 64]])
        #expect(scenario.viewModel.edit.editedDuration == 64)
        #expect(scenario.viewModel.selectedSegmentIndex == 1)
        #expect(scenario.toast.message == "Split at \(DurationText.editor(20))")
    }

    @Test func splittingAtAnEdgeExplains() async {
        let scenario = await makeScenario()
        scenario.viewModel.clips.splitClip()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move playhead onto the clip")
    }

    @Test func splittingAtTheEndExplainsToo() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 64)
        scenario.viewModel.clips.splitClip()
        #expect(scenario.viewModel.edit.timeline.segments.count == 1)
        #expect(scenario.toast.message == "Move playhead onto the clip")
        #expect(!scenario.viewModel.canUndo)
    }

    @Test func deletingThePickedClip() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.clips.splitClip()
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
        scenario.viewModel.clips.deleteClip(scenario.viewModel.edit.timeline.segments[0].id)
        #expect(scenario.toast.message == "Keep at least one clip")
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(!scenario.viewModel.canUndo)
    }

    @Test func deletingBAndDLeavesAAndC() async {
        let scenario = await makeScenario()
        for cut in [16.0, 32, 48] {
            scenario.player.seek(to: cut)
            scenario.viewModel.clips.splitClip()
        }
        // The last split left D picked.
        scenario.viewModel.perform(.deleteClip)
        scenario.viewModel.clips.deleteClip(scenario.viewModel.edit.timeline.segments[1].id)
        #expect(spans(scenario.viewModel) == [[0, 16], [32, 48]])
        #expect(scenario.viewModel.edit.editedDuration == 32)
    }

    @Test func theSelectionIsNotThePlayhead() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 20)
        scenario.viewModel.clips.splitClip()
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
        scenario.viewModel.clips.splitClip()
        scenario.player.seek(to: 30)
        scenario.viewModel.clips.deleteClip(scenario.viewModel.edit.timeline.segments[0].id)
        #expect(scenario.player.currentTime == 20)
    }

    // MARK: - Undo

    @Test func undoAndRedoWalkThroughTrimCutAndDelete() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        dragHandle(.start, to: 4, on: viewModel)
        scenario.player.seek(to: 16)
        viewModel.clips.splitClip()
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
        viewModel.clips.splitClip()
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
        scenario.viewModel.look.setAdjustment(.exposure, 30)
        scenario.viewModel.audio.setVoiceEnhancement(.strong)
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
        scenario.viewModel.look.pickFilter(.mono)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.filter == .original)
        #expect(scenario.viewModel.edit.timeline.trimStart == 4)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    // MARK: - Clean Up

    @Test func cleanUpFindsSuggestionsAndRemovesNothing() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.clips.analysis == .idle)
        await scenario.viewModel.clips.analyzeIfNeeded()
        #expect(scenario.viewModel.clips.analysis == .done)
        #expect(scenario.editor.cleanUpScript == "Okay, real talk.")
        #expect(scenario.viewModel.clips.cleanUpSuggestions.map(\.span) == [TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 31)])
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    @Test func cleanUpListensOnce() async {
        let scenario = await makeScenario()
        await scenario.viewModel.clips.analyzeIfNeeded()
        scenario.editor.silences = []
        await scenario.viewModel.clips.analyzeIfNeeded()
        #expect(scenario.viewModel.clips.cleanUpSuggestions.count == 2)
    }

    @Test func aTakeThatCantBeHeardSaysSo() async {
        let editor = FakeTakeEditor()
        editor.cleanUpFails = true
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.clips.analyzeIfNeeded()
        #expect(scenario.viewModel.clips.analysis == .failed)
        #expect(scenario.toast.message == "Couldn't listen to this take")
        #expect(scenario.viewModel.clips.cleanUpSuggestions.isEmpty)
    }

    @Test func nothingFoundIsAllClean() async {
        let editor = FakeTakeEditor()
        editor.silences = []
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.clips.analyzeIfNeeded()
        #expect(scenario.viewModel.clips.analysis == .done)
        #expect(scenario.viewModel.clips.pauseCandidates.isEmpty && scenario.viewModel.clips.wordCandidates.isEmpty)
        #expect(scenario.viewModel.clips.cleanUpApplyLabel == "Nothing selected")
    }

    @Test func tappingASuggestionMovesThePlayheadThere() async throws {
        let scenario = await makeScenario()
        await scenario.viewModel.clips.analyzeIfNeeded()
        let found = scenario.viewModel.clips.cleanUpSuggestions
        scenario.viewModel.togglePlayback()
        scenario.viewModel.clips.tapCleanUpCard(found[1].id)
        let start = try #require(scenario.viewModel.edit.timeline.editedSpan(of: found[1])?.start)
        #expect(abs(scenario.player.currentTime - (start - 0.4)) < 0.000_1)
        #expect(!scenario.player.isPlaying)
        // The tap also switches its mark.
        #expect(!scenario.viewModel.clips.isMarked(found[1]))
    }

    @Test func suggestionsOutsideTheHandlesArentListed() async {
        let scenario = await makeScenario()
        dragHandle(.end, to: 20, on: scenario.viewModel)
        await scenario.viewModel.clips.analyzeIfNeeded()
        #expect(scenario.viewModel.clips.cleanUpSuggestions.map(\.span) == [TimeSpan(start: 10, end: 12)])
    }

    @Test func undoingAnEarlierStepKeepsWhatCleanUpFound() async {
        let scenario = await makeScenario()
        dragHandle(.start, to: 2, on: scenario.viewModel)
        await scenario.viewModel.clips.analyzeIfNeeded()
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.timeline.isWhole)
        #expect(scenario.viewModel.clips.cleanUpSuggestions.count == 2)
    }

    @Test func fillersAndRetakesComeFromTheTranscript() async {
        let editor = FakeTakeEditor()
        editor.silences = []
        editor.transcript = TakeTranscript(
            words: [("So", 0.0), ("um,", 0.25), ("today", 0.5)].map { TimedWord(text: $0.0, start: $0.1, end: $0.1 + 0.25) },
            languageCode: "en"
        )
        let scenario = await makeScenario(editor: editor)
        await scenario.viewModel.clips.analyzeIfNeeded()
        #expect(scenario.viewModel.clips.cleanUpSuggestions.map(\.kind) == [.filler])
        #expect(scenario.viewModel.clips.cleanUpSuggestions.first?.title == "“um,”")
    }

    // MARK: - Captions and look

    @Test func captionsComeFromTheScript() async {
        let scenario = await makeScenario()
        scenario.viewModel.captions.makeCaptions()
        await scenario.viewModel.jobs.finished(.captions)
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

    /// Nowhere to keep the edit: the editor stays open and says why, with Leave anyway; asked again, it leaves.
    @Test func doneThatCantSaveAnywhereStaysAndSaysWhy() async {
        let repository = FakeTakeRepository()
        let drafts = FakeDraftStore()
        let scenario = await makeScenario(drafts: drafts, repository: repository)
        repository.failsToSave = true
        drafts.failsToSave = true
        dragHandle(.start, to: 4, on: scenario.viewModel)
        #expect(scenario.viewModel.finish(.share) == nil)
        #expect(scenario.toast.message == "Couldn't save the edits · Free up space on this iPhone")
        #expect(scenario.toast.action?.title == "Leave anyway")
        #expect(!scenario.player.isStopped)
        #expect(scenario.viewModel.draftKeeper.state == .failed(.noSpace))
        #expect(scenario.viewModel.finish(.share) == .notYet)
        #expect(scenario.player.isStopped)
    }

    @Test func cancelThatCantWriteTheDraftNeverSaysDraftSavedAndStaysOnce() async {
        let drafts = FakeDraftStore()
        drafts.failsToSave = true
        let scenario = await makeScenario(drafts: drafts)
        dragHandle(.end, to: 30, on: scenario.viewModel)
        #expect(!scenario.viewModel.cancel())
        #expect(drafts.drafts.isEmpty)
        #expect(scenario.toast.message == "Couldn't save the edits · Free up space on this iPhone")
        #expect(!scenario.player.isStopped)
        // Space freed: Back now keeps the draft and leaves.
        drafts.failsToSave = false
        #expect(scenario.viewModel.cancel())
        #expect(drafts.drafts.count == 1)
        #expect(scenario.toast.message == "Draft saved")

        drafts.failsToSave = true
        let notYet = await makeScenario(drafts: drafts)
        #expect(notYet.viewModel.finish(.notYet) == nil)
        #expect(notYet.toast.message == "Couldn't save the edits · Free up space on this iPhone")
        notYet.toast.action?.perform()
        #expect(notYet.player.isStopped)
    }

    /// A failure that isn't a full iPhone isn't blamed on space.
    @Test func aWriteThatFailsForAnotherReasonSaysTryAgain() async {
        let drafts = FakeDraftStore()
        drafts.failsToSave = true
        drafts.saveError = CocoaError(.fileWriteNoPermission)
        let scenario = await makeScenario(drafts: drafts)
        dragHandle(.end, to: 30, on: scenario.viewModel)
        scenario.viewModel.cancel()
        #expect(scenario.toast.message == "Couldn't save the edits · Try again")
    }

    /// Back while the video is still opening, or after it couldn't be opened, leaves the draft from before as it was.
    @Test func backBeforeTheVideoOpensKeepsTheDraft() async {
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts)
        dragHandle(.end, to: 30, on: first.viewModel)
        first.viewModel.cancel()
        #expect(drafts.drafts.count == 1)

        let loading = await makeScenario(drafts: drafts, takes: first.takes, prepares: false)
        #expect(loading.viewModel.finish(.back) == .back)
        #expect(drafts.drafts.count == 1)

        let editor = FakeTakeEditor()
        editor.duration = nil
        let unavailable = await makeScenario(editor: editor, drafts: drafts, takes: first.takes)
        #expect(unavailable.viewModel.source == .unavailable)
        unavailable.viewModel.cancel()
        #expect(drafts.drafts.count == 1)

        let reopened = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(reopened.viewModel.edit.timeline.trimEnd == 30)
        #expect(reopened.viewModel.canUndo)
    }

    /// A draft that can't be read opens the take's own edit and says a copy is kept; one read in part says so and is written again.
    @Test func aDraftThatDidntReadWholeIsSaid() async {
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts)
        let takeID = first.takes.takes[0].id
        drafts.readings[takeID] = .unreadable
        let unreadable = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(unreadable.toast.message == "Couldn't open your draft · A copy is kept on this iPhone")
        #expect(unreadable.viewModel.draftKeeper.state == .clean)

        dragHandle(.end, to: 30, on: first.viewModel)
        first.viewModel.cancel()
        guard let kept = drafts.drafts[takeID] else {
            Issue.record("Back should have kept a draft")
            return
        }
        drafts.readings[takeID] = .draft(kept, partial: true)
        let partial = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(partial.toast.message == "Draft restored · Some parts couldn't be read")
        #expect(partial.viewModel.edit.timeline.trimEnd == 30)
        #expect(partial.viewModel.draftKeeper.state == .saving)
    }

    /// Done waits for work that changes the edit when it ends and says which; Back keeps the draft, stops it and says so.
    @Test func doneWaitsForCaptionsAndBackSaysTheyStopped() async {
        let drafts = FakeDraftStore()
        let scenario = await makeScenario(drafts: drafts)
        dragHandle(.end, to: 30, on: scenario.viewModel)
        scenario.viewModel.captions.captionState = .working(.preparing)
        scenario.viewModel.askIfReadyToPost()
        #expect(scenario.viewModel.sheet == nil)
        #expect(scenario.toast.message == "Captions are still being made · Wait a moment")
        #expect(scenario.viewModel.pendingWork == .captions)

        #expect(scenario.viewModel.finish(.back) == .back)
        #expect(scenario.toast.message == "Draft saved · Captions weren't finished")
        #expect(drafts.drafts.count == 1)

        let plain = await makeScenario()
        dragHandle(.end, to: 30, on: plain.viewModel)
        #expect(plain.viewModel.pendingWork == nil)
        plain.viewModel.askIfReadyToPost()
        #expect(plain.viewModel.sheet == .done)
    }

    /// A file the edit names that is gone stays marked over the preview (never only a toast that hid "Draft restored"), until it
    /// is removed; Undo bringing it back marks it again.
    @Test func missingMediaStaysMarkedUntilRemoved() async {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        var edit = TakeEdit(sourceDuration: 64, aspect: .portrait)
        edit.music = [MusicClip(fileName: "gone-\(UUID().uuidString).m4a", title: "Loop", fileDuration: 60, start: 0, length: 10)]
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let scenario = await makeScenario(script: nil, takes: takes)
        #expect(scenario.viewModel.showsMissingMediaNotice)
        #expect(scenario.viewModel.canRemoveMissingMedia)
        #expect(scenario.toast.message == nil)
        scenario.viewModel.removeMissingMedia(scenario.viewModel.missingMedia)
        #expect(scenario.viewModel.edit.music.isEmpty)
        #expect(!scenario.viewModel.showsMissingMediaNotice)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.showsMissingMediaNotice)
        scenario.viewModel.hideMissingMediaNotice()
        #expect(!scenario.viewModel.showsMissingMediaNotice)
    }

    /// The chip follows what is on disk: Saving… after a change, Saved once the draft is written, nothing to say with no change.
    @Test func theChipSaysSavedOnlyOnceTheDraftIsWritten() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.draftKeeper.state == .clean)
        dragHandle(.end, to: 30, on: scenario.viewModel)
        #expect(scenario.viewModel.draftKeeper.state == .saving)
        #expect(scenario.viewModel.saveDraft())
        #expect(scenario.viewModel.draftKeeper.state == .saved)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.draftKeeper.state == .clean)
    }

    /// "Yes, share" or "Download" whose edit couldn't be saved on the take: the review goes on as "Not yet" (the edit is a draft), never
    /// sharing or saving the video as it was before the edit.
    @Test func aDoneThatCouldntSaveIsANotYetForTheReview() async {
        let repository = FakeTakeRepository()
        let scenario = await makeScenario(repository: repository)
        repository.failsToSave = true
        dragHandle(.start, to: 4, on: scenario.viewModel)
        #expect(scenario.viewModel.finish(.share) == .notYet)
        let saved = await makeScenario()
        dragHandle(.start, to: 4, on: saved.viewModel)
        #expect(saved.viewModel.finish(.download) == .download)
    }

    /// Cue went to the background and the draft couldn't be written (a full iPhone): said at once, and written on the way back.
    @Test func aDraftThatCantBeKeptInTheBackgroundIsSaidAndTriedAgain() async {
        let drafts = FakeDraftStore()
        let scenario = await makeScenario(drafts: drafts)
        dragHandle(.start, to: 4, on: scenario.viewModel)
        drafts.failsToSave = true
        scenario.viewModel.pauseAndKeepDraft()
        #expect(scenario.toast.message == "Couldn't save the edits · Free up space on this iPhone")
        #expect(drafts.drafts.isEmpty)
        drafts.failsToSave = false
        scenario.viewModel.becameActive()
        #expect(drafts.drafts.count == 1)
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
