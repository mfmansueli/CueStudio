//
//  QuickCreatorViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Quick Creator tools in Quick edit: texts, media, voice-overs, speed, Remove Pauses,
/// transitions, styles and the cover. Every change is an undo step (a drag or a sheet is one), and
/// Done saves it on the take.
@MainActor
@Suite("Quick Creator")
struct QuickCreatorViewModelTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let takes: TakeLibraryService
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let recorder: FakeVoiceRecorder
        let toast: ToastService
    }

    private func makeScenario(editor: FakeTakeEditor = FakeTakeEditor()) async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let recorder = FakeVoiceRecorder()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: recorder
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, takes: takes, editor: editor, player: player, recorder: recorder, toast: toast)
    }

    private func photo(_ name: String = "photo-\(UUID().uuidString).jpg") -> ImportedMedia {
        ImportedMedia(kind: .photo, fileName: name, aspect: 1, duration: nil)
    }

    // MARK: - Tools

    @Test func toolsAreGroupedByIntent() {
        #expect(QuickEditCategory.edit.tools == [.trim, .cleanUp, .removePauses, .speed])
        #expect(QuickEditCategory.add.tools == [.text, .media, .voiceOver])
        #expect(QuickEditCategory.polish.tools == [.style, .audio, .adjust, .filters, .crop, .transitions])
        #expect(QuickEditCategory.captions.tools == [.captions])
        #expect(QuickEditCategory.cover.tools == [.cover])
    }

    @Test func eachCategoryOpensOnTheToolUsedLast() async {
        let scenario = await makeScenario()
        scenario.viewModel.tool = .speed
        scenario.viewModel.tool = .text
        #expect(scenario.viewModel.lastTool[.edit] == .speed)
        #expect(scenario.viewModel.lastTool[.add] == .text)
    }

    // MARK: - Text

    @Test func aTextIsAddedAtThePlayheadInTheProjectsStyle() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 10)
        scenario.viewModel.addText(.title)
        let text = try? #require(scenario.viewModel.edit.texts.first)
        #expect(text?.span == TimeSpan(start: 10, end: 13))
        #expect(text?.font == .classic)
        #expect(scenario.viewModel.selectedTextID == text?.id)
        #expect(scenario.viewModel.editingTextID == text?.id)
        #expect(scenario.viewModel.textBars.map(\.span) == [TimeSpan(start: 10, end: 13)])
    }

    @Test func aTextNearTheEndStaysInsideTheEdit() async {
        let scenario = await makeScenario()
        scenario.player.seek(to: 63)
        scenario.viewModel.addText(.subtitle)
        #expect(scenario.viewModel.edit.texts.first?.span == TimeSpan(start: 60, end: 64))
    }

    @Test func writingInTheSheetIsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.hook)
        let id = viewModel.edit.texts[0].id
        let steps = viewModel.history.past.count
        viewModel.beginChange()
        for text in ["S", "St", "Stop"] { viewModel.updateText(id) { $0.text = text } }
        viewModel.updateText(id) { $0.color = .yellow }
        viewModel.endChange()
        #expect(viewModel.history.past.count == steps + 1)
        #expect(viewModel.edit.texts[0].text == "Stop")

        viewModel.undo()
        #expect(viewModel.edit.texts[0].text == TextOverlayRole.hook.placeholder)
        viewModel.undo()
        #expect(viewModel.edit.texts.isEmpty)
        viewModel.redo()
        viewModel.redo()
        #expect(viewModel.edit.texts[0].color == .yellow)
    }

    @Test func aTextStaysOnWhatIsSaidWhenSomethingBeforeItIsCut() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 20)
        viewModel.addText(.title)
        scenario.player.seek(to: 5)
        viewModel.startRemovingPart()
        viewModel.removePart()
        #expect(viewModel.textBars.first?.span == TimeSpan(start: 18, end: 21))
    }

    @Test func dragsOnTheTrackMoveAndStretchATextInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        let steps = viewModel.history.past.count
        let bar = viewModel.textBars[0]
        viewModel.beginChange()
        viewModel.moveBar(bar, toStart: 5)
        viewModel.moveBar(bar, toStart: 8)
        viewModel.endChange()
        #expect(viewModel.textBars[0].span == TimeSpan(start: 8, end: 11))
        let moved = viewModel.textBars[0]
        viewModel.beginChange()
        viewModel.resizeBar(moved, edge: .end, to: 20)
        viewModel.endChange()
        #expect(viewModel.textBars[0].span == TimeSpan(start: 8, end: 20))
        #expect(viewModel.history.past.count == steps + 2)
    }

    @Test func aQuickStyleRestylesOneText() async {
        let scenario = await makeScenario()
        scenario.viewModel.addText(.callout)
        let id = scenario.viewModel.edit.texts[0].id
        scenario.viewModel.applyStyle(.social, toText: id)
        #expect(scenario.viewModel.edit.texts[0].background == .pill)
        #expect(scenario.viewModel.edit.creatorStyle == nil)
    }

    @Test func deletingATextIsUndoable() async {
        let scenario = await makeScenario()
        scenario.viewModel.addText(.title)
        let id = scenario.viewModel.edit.texts[0].id
        scenario.viewModel.deleteText(id)
        #expect(scenario.viewModel.edit.texts.isEmpty)
        #expect(scenario.viewModel.selectedTextID == nil)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.texts.map(\.id) == [id])
    }

    // MARK: - Style

    @Test func aStyleSetsTextsCaptionsAndFilterInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        viewModel.applyCreatorStyle(.bold)
        #expect(viewModel.edit.creatorStyle == .bold)
        #expect(viewModel.edit.captionStyle == .bold)
        #expect(viewModel.edit.filter == .vivid)
        #expect(viewModel.edit.texts[0].isUppercase)
        #expect(scenario.toast.message == "Bold style applied")
        // New texts start from it.
        viewModel.addText(.hook)
        #expect(viewModel.edit.texts[1].hasOutline)

        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.creatorStyle == nil)
        #expect(viewModel.edit.filter == .original)
        #expect(!viewModel.edit.texts[0].isUppercase)
    }

    // MARK: - Speed

    @Test func theWholeVideoAtDoubleSpeed() async {
        let scenario = await makeScenario()
        scenario.viewModel.setSpeed(.double)
        #expect(scenario.viewModel.edit.editedDuration == 32)
        #expect(scenario.viewModel.durationChange == "1:04 → 0:32")
        #expect(scenario.viewModel.currentSpeed == .double)
        scenario.viewModel.undo()
        #expect(scenario.viewModel.edit.editedDuration == 64)
    }

    @Test func oneSectionSlowerThanTheRest() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 32)
        viewModel.cut()
        viewModel.tool = .speed
        viewModel.speedScope = .section
        scenario.player.seek(to: 40)
        viewModel.setSpeed(.half)
        #expect(viewModel.edit.timeline.segments.map(\.speed) == [1, 0.5])
        #expect(viewModel.edit.editedDuration == 96)
        #expect(viewModel.currentSpeed == .half)
        #expect(viewModel.speedDetail.hasPrefix("Section 2 of 2"))
    }

    // MARK: - Remove Pauses

    @Test func pausesAreFoundAndAddedUp() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        #expect(scenario.viewModel.removablePauses.count == 2)
        #expect(scenario.viewModel.pausesTitle == "Found 2 pauses")
        #expect(scenario.viewModel.pausesTotalLabel == "Total: 3.0s")
        #expect(scenario.viewModel.edit.timeline.isWhole)
    }

    @Test func thePreviewPlaysWithoutThePausesAndCancelPutsThemBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        let steps = viewModel.history.past.count
        viewModel.previewPauses()
        #expect(viewModel.isPreviewingPauses)
        #expect(viewModel.edit.editedDuration == 61)
        #expect(scenario.player.isPlaying)
        #expect(viewModel.history.past.count == steps)
        // Still says what it takes out.
        #expect(viewModel.pausesTitle == "Found 2 pauses")

        viewModel.cancelPausePreview()
        #expect(!viewModel.isPreviewingPauses)
        #expect(viewModel.edit.timeline.isWhole)
        #expect(viewModel.removablePauses.count == 2)
    }

    @Test func applyAfterThePreviewIsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        let steps = viewModel.history.past.count
        viewModel.previewPauses()
        viewModel.applyPauses()
        #expect(!viewModel.isPreviewingPauses)
        #expect(viewModel.edit.editedDuration == 61)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(scenario.toast.message == "Removed 2 pauses · 3.0s")
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
        #expect(viewModel.removablePauses.count == 2)
    }

    @Test func leavingTheToolOrUndoingDropsThePreview() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        viewModel.tool = .removePauses
        viewModel.previewPauses()
        viewModel.tool = .trim
        #expect(viewModel.edit.timeline.isWhole)
        viewModel.tool = .removePauses
        viewModel.previewPauses()
        #expect(viewModel.canUndo)
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
        #expect(!viewModel.isPreviewingPauses)
    }

    @Test func doneDuringThePreviewKeepsWhatWasHeard() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        scenario.viewModel.previewPauses()
        scenario.viewModel.done()
        #expect(scenario.takes.takes[0].edit?.editedDuration == 61)
    }

    @Test func applyWithoutAPreviewTakesThePausesOut() async {
        let scenario = await makeScenario()
        await scenario.viewModel.analyzeIfNeeded()
        scenario.viewModel.applyPauses()
        #expect(scenario.viewModel.edit.keptSpans == [
            TimeSpan(start: 0, end: 10), TimeSpan(start: 12, end: 30), TimeSpan(start: 31, end: 64),
        ])
        #expect(scenario.viewModel.removablePauses.isEmpty)
    }

    // MARK: - Transitions

    @Test func oneTransitionOnEveryCut() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        for time in [20.0, 40] {
            scenario.player.seek(to: time)
            viewModel.cut()
        }
        #expect(viewModel.cuts.map(\.index) == [1, 2])
        let steps = viewModel.history.past.count
        viewModel.setTransitionOnEveryCut(.slide)
        #expect(viewModel.edit.timeline.segments.map(\.transitionIn) == [.hardCut, .slide, .slide])
        #expect(viewModel.history.past.count == steps + 1)
        viewModel.setTransition(.fade, atJoin: 2)
        #expect(viewModel.edit.timeline.transition(atJoin: 2) == .fade)
    }

    // MARK: - Media

    @Test func aPhotoIsAddedAtThePlayheadAndTheNextOneAfterIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        viewModel.addMedia(photo())
        #expect(viewModel.mediaBars.map(\.span) == [TimeSpan(start: 10, end: 13)])
        #expect(viewModel.selectedMediaID == viewModel.edit.media[0].id)
        scenario.player.seek(to: 11)
        viewModel.addMedia(photo())
        #expect(viewModel.mediaBars.map(\.span) == [TimeSpan(start: 10, end: 13), TimeSpan(start: 13, end: 16)])
    }

    @Test func mediaNeverOverlapsWhenMoved() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        viewModel.addMedia(photo())
        scenario.player.seek(to: 20)
        viewModel.addMedia(photo())
        let second = viewModel.mediaBars[1]
        viewModel.moveBar(second, toStart: 5)
        #expect(viewModel.mediaBars[1].span == TimeSpan(start: 13, end: 16))
        viewModel.resizeBar(viewModel.mediaBars[0], edge: .end, to: 30)
        #expect(viewModel.mediaBars[0].span.end == 13)
    }

    @Test func aVideoIsntStretchedPastItsLength() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMedia(ImportedMedia(kind: .video, fileName: "clip.mov", aspect: 9.0 / 16.0, duration: 4))
        #expect(viewModel.mediaBars[0].span == TimeSpan(start: 0, end: 4))
        viewModel.resizeBar(viewModel.mediaBars[0], edge: .end, to: 10)
        #expect(viewModel.mediaBars[0].span == TimeSpan(start: 0, end: 4))
    }

    @Test func aWindowIsLaidOutAndUndone() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMedia(photo())
        let id = viewModel.edit.media[0].id
        viewModel.updateMedia(id) {
            $0.layout = .window
            $0.shape = .square
            $0.width = 0.4
        }
        #expect(viewModel.selectedMedia?.layout == .window)
        viewModel.undo()
        #expect(viewModel.edit.media[0].layout == .fullFrame)
        viewModel.deleteMedia(id)
        #expect(viewModel.edit.media.isEmpty)
    }

    // MARK: - Voice-over

    @Test func aVoiceOverRecordsFromThePlayheadWithTheVideoSilent() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 12)
        await viewModel.startVoiceOver()
        #expect(viewModel.isRecordingVoiceOver)
        #expect(scenario.player.isMuted)
        #expect(scenario.player.isPlaying)
        #expect(!viewModel.canUndo)

        viewModel.stopVoiceOver()
        #expect(!viewModel.isRecordingVoiceOver)
        #expect(!scenario.player.isMuted)
        let clip = try? #require(viewModel.edit.voiceOvers.first)
        #expect(clip?.anchor == 12)
        #expect(clip?.duration == 4)
        #expect(viewModel.reviewedVoiceOverID == clip?.id)
        #expect(viewModel.voiceOverBars.map(\.span) == [TimeSpan(start: 12, end: 16)])
        // It plays back from where it starts.
        #expect(scenario.player.currentTime == 12)
        #expect(scenario.player.isPlaying)

        viewModel.keepVoiceOver()
        #expect(viewModel.reviewedVoiceOverID == nil)
        viewModel.undo()
        #expect(viewModel.edit.voiceOvers.isEmpty)
    }

    @Test func redoRecordsAgainFromTheSameMoment() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 8)
        await viewModel.startVoiceOver()
        viewModel.stopVoiceOver()
        scenario.player.seek(to: 30)
        await viewModel.redoVoiceOver()
        #expect(viewModel.edit.voiceOvers.isEmpty)
        #expect(viewModel.recordingStart == 8)
        viewModel.stopVoiceOver()
        #expect(viewModel.edit.voiceOvers.map(\.anchor) == [8])
    }

    @Test func withoutTheMicrophoneNothingRecords() async {
        let scenario = await makeScenario()
        scenario.recorder.allowed = false
        await scenario.viewModel.startVoiceOver()
        #expect(!scenario.viewModel.isRecordingVoiceOver)
        #expect(scenario.toast.message == "Turn on the microphone for Cue in Settings to record a voice-over")
    }

    @Test func aVoiceOverKeepsItsVolumeAndCanBeDeleted() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.startVoiceOver()
        viewModel.stopVoiceOver()
        let id = viewModel.edit.voiceOvers[0].id
        viewModel.setVoiceOverVolume(id, volume: 3)
        #expect(viewModel.edit.voiceOvers[0].volume == 1)
        viewModel.setVoiceOverVolume(id, volume: 0.4)
        #expect(viewModel.edit.voiceOvers[0].volume == 0.4)
        viewModel.deleteVoiceOver(id)
        #expect(viewModel.edit.voiceOvers.isEmpty)
    }

    @Test func cancelDropsARecordingInProgress() async {
        let scenario = await makeScenario()
        await scenario.viewModel.startVoiceOver()
        scenario.viewModel.cancel()
        #expect(scenario.recorder.cancelled)
        #expect(scenario.viewModel.edit.voiceOvers.isEmpty)
    }

    // MARK: - Cover

    @Test func theFrameUnderThePlayheadBecomesTheCover() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 20)
        viewModel.useFrameAsCover()
        #expect(viewModel.edit.cover?.source == .frame(20))
        viewModel.setCoverTitle("3 erros que todo creator comete")
        viewModel.setCoverTitlePosition(2)
        #expect(viewModel.edit.cover?.title == "3 erros que todo creator comete")
        #expect(viewModel.edit.cover?.titleY == 1 - OverlayPoint.margin)
        viewModel.undo()
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.cover == nil)
    }

    @Test func theCoverFollowsTheProjectStyle() async {
        let scenario = await makeScenario()
        scenario.viewModel.applyCreatorStyle(.minimal)
        scenario.viewModel.useFrameAsCover()
        #expect(scenario.viewModel.edit.cover?.style == .minimal)
        scenario.viewModel.applyCreatorStyle(.social)
        #expect(scenario.viewModel.edit.cover?.style == .social)
    }

    // MARK: - Done

    @Test func doneSavesEverythingOnTheTake() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        viewModel.addMedia(photo("kept.jpg"))
        viewModel.setSpeed(.oneAndAHalf)
        viewModel.useFrameAsCover()
        viewModel.done()
        let saved = scenario.takes.takes[0]
        #expect(saved.edit?.texts.count == 1)
        #expect(saved.edit?.media.map(\.fileName) == ["kept.jpg"])
        #expect(saved.edit?.cover != nil)
        #expect(abs((saved.edit?.editedDuration ?? 0) - 64 / 1.5) < 0.001)
        #expect(saved.isEdited)
    }
}
