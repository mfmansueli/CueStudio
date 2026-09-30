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
        let styles: FakeTextStyleStore
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
        let styles = FakeTextStyleStore()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: recorder, styles: styles
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, takes: takes, editor: editor, player: player, recorder: recorder, toast: toast, styles: styles)
    }

    private func photo(_ name: String = "photo-\(UUID().uuidString).jpg") -> ImportedMedia {
        ImportedMedia(kind: .photo, fileName: name, aspect: 1, duration: nil)
    }

    // MARK: - Tools

    @Test func toolsAreGroupedByIntent() {
        #expect(QuickEditCategory.toolbar == [.edit, .text, .captions, .audio, .media, .adjust])
        #expect(QuickEditCategory.edit.tools == [.trim, .cleanUp, .speed])
        #expect(QuickEditCategory.text.tools == [.text, .style])
        #expect(QuickEditCategory.captions.tools == [.captions])
        #expect(QuickEditCategory.audio.tools == [.audio, .music, .voiceOver])
        #expect(QuickEditCategory.media.tools == [.media])
        #expect(QuickEditCategory.adjust.tools == [.adjust, .filters, .crop, .background])
        // The cover is part of finishing, next to Done.
        #expect(QuickEditCategory.finish.tools == [.cover])
    }

    @Test func eachCategoryOpensOnTheToolUsedLast() async {
        let scenario = await makeScenario()
        scenario.viewModel.tool = .speed
        scenario.viewModel.tool = .text
        #expect(scenario.viewModel.lastTool[.edit] == .speed)
        #expect(scenario.viewModel.lastTool[.text] == .text)
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

    @Test func aPresetRestylesOneText() async {
        let scenario = await makeScenario()
        scenario.viewModel.addText(.callout)
        scenario.viewModel.addText(.title)
        scenario.viewModel.applyPreset(.label, to: .selected)
        let texts = scenario.viewModel.edit.texts
        #expect(texts[1].background == .box)
        #expect(texts[1].backgroundColor == .yellow)
        #expect(texts[1].preset == .label)
        // Only the picked one, and new texts don't follow it.
        #expect(texts[0].preset == .cue)
        #expect(scenario.viewModel.edit.textPreset == nil)
        #expect(scenario.toast.message == "Label on this text")
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

    @Test func newTextsStartInCuesPreset() async {
        let scenario = await makeScenario()
        scenario.viewModel.addText(.title)
        let text = scenario.viewModel.edit.texts[0]
        #expect(text.preset == .cue)
        #expect(text.weight == .heavy)
    }

    @Test func aPresetOnEveryTextIsOneStepAndLeavesThePictureAlone() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        viewModel.setFilter(.film)
        viewModel.useFrameAsCover()
        let cover = viewModel.edit.cover
        let steps = viewModel.history.past.count
        viewModel.applyPreset(.impact, to: .allTexts)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(viewModel.edit.texts[0].isUppercase)
        #expect(viewModel.edit.texts[0].hasOutline)
        #expect(viewModel.edit.textPreset == .impact)
        #expect(scenario.toast.message == "Impact on every text")
        // Type only: the filter, the cover and the captions stay.
        #expect(viewModel.edit.filter == .film)
        #expect(viewModel.edit.cover == cover)
        #expect(viewModel.edit.captionLook == nil)
        // New texts start from it.
        viewModel.addText(.hook)
        #expect(viewModel.edit.texts[1].preset == .impact)

        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.textPreset == nil)
        #expect(!viewModel.edit.texts[0].isUppercase)
    }

    @Test func keepMyChangesKeepsWhatWasSetByHand() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        let id = viewModel.edit.texts[0].id
        viewModel.customizeText(id, .color) { $0.color = .pink }
        #expect(viewModel.edit.texts[0].customized == [.color])

        viewModel.applyPreset(.pop, to: .allTexts, keepingCustomizations: true)
        #expect(viewModel.edit.texts[0].color == .pink)
        #expect(viewModel.edit.texts[0].hasOutline)
        #expect(viewModel.edit.texts[0].customized == [.color])

        viewModel.applyPreset(.editorial, to: .allTexts, keepingCustomizations: false)
        #expect(viewModel.edit.texts[0].color == .white)
        #expect(viewModel.edit.texts[0].font == .serif)
        #expect(viewModel.edit.texts[0].customized.isEmpty)
    }

    @Test func aPresetOnTheCaptionsLeavesTheTextsAlone() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        let text = viewModel.edit.texts[0]
        viewModel.applyPreset(.pop, to: .allCaptions)
        #expect(viewModel.edit.captionLook == TypePreset.pop.look(for: .caption))
        #expect(viewModel.edit.captionPreset == .pop)
        #expect(viewModel.edit.texts[0] == text)
        #expect(scenario.toast.message == "Pop on the captions")
        viewModel.undo()
        #expect(viewModel.edit.captionLook == nil)
    }

    @Test func myStyleIsSavedFromATextAndReused() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        let id = viewModel.edit.texts[0].id
        viewModel.customizeText(id, .color) { $0.color = .green }
        viewModel.customizeText(id, .tracking) { $0.tracking = 0.1 }
        viewModel.saveMyStyle()
        #expect(scenario.styles.myStyle?.color == .green)
        #expect(scenario.styles.myStyle?.tracking == 0.1)
        #expect(viewModel.myStyle == scenario.styles.myStyle)
        #expect(scenario.toast.message == "Saved as My style")

        viewModel.addText(.hook)
        viewModel.applyMyStyle(to: .allTexts)
        #expect(viewModel.edit.texts.allSatisfy { $0.color == .green && $0.tracking == 0.1 })
        #expect(viewModel.edit.textPreset == nil)
        #expect(scenario.toast.message == "My style on every text")
    }

    @Test func myStyleOnCaptionsStaysReadable() async {
        let scenario = await makeScenario()
        scenario.styles.myStyle = TextLook(sizeScale: 2.2, color: .yellow)
        let viewModel = QuickEditViewModel(
            take: scenario.viewModel.take, takes: scenario.takes, library: scenario.viewModel.library, editing: scenario.editor,
            drafts: FakeDraftStore(), toast: scenario.toast, player: scenario.player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: scenario.styles
        )
        await viewModel.prepare()
        viewModel.applyMyStyle(to: .allCaptions)
        #expect(viewModel.edit.captionLook?.color == .yellow)
        #expect(viewModel.edit.captionLook?.sizeScale == 1.3)
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
        #expect(scenario.viewModel.pausesTotalLabel == "Total: \(TestData.decimal("3.0"))s")
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
        #expect(scenario.toast.message == "Removed 2 pauses · \(TestData.decimal("3.0"))s")
        viewModel.undo()
        #expect(viewModel.edit.timeline.isWhole)
        #expect(viewModel.removablePauses.count == 2)
    }

    @Test func leavingTheToolOrUndoingDropsThePreview() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        viewModel.tool = .cleanUp
        viewModel.previewPauses()
        viewModel.tool = .trim
        #expect(viewModel.edit.timeline.isWhole)
        viewModel.tool = .cleanUp
        viewModel.previewPauses()
        // Switching to Review puts the pauses back too.
        viewModel.cleanUpSection = .review
        #expect(viewModel.edit.timeline.isWhole)
        viewModel.cleanUpSection = .pauses
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

    @Test func aPhotoIsAddedAtThePlayheadOnTopOfWhatIsThere() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        viewModel.addMedia(photo())
        #expect(viewModel.mediaBars.map(\.span) == [TimeSpan(start: 10, end: 13)])
        #expect(viewModel.selectedMediaID == viewModel.edit.media[0].id)
        scenario.player.seek(to: 11)
        viewModel.addMedia(photo())
        // Photos and videos can overlap now; the newer one stacks on top.
        #expect(viewModel.mediaBars.map(\.span) == [TimeSpan(start: 10, end: 13), TimeSpan(start: 11, end: 14)])
        #expect(viewModel.edit.media.map(\.stackOrder) == [0, 1])
    }

    @Test func mediaMovesFreelyUpToThreeAtOnce() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        for start in [10.0, 20, 30] {
            scenario.player.seek(to: start)
            viewModel.addMedia(photo())
        }
        viewModel.moveBar(viewModel.mediaBars[1], toStart: 11)
        #expect(viewModel.mediaBars[1].span == TimeSpan(start: 11, end: 14))
        // A third on the same moment still fits; stretching over it keeps it to three.
        viewModel.moveBar(viewModel.mediaBars[2], toStart: 12)
        #expect(viewModel.mediaBars[2].span == TimeSpan(start: 12, end: 15))
        scenario.player.seek(to: 12.5)
        viewModel.addMedia(photo())
        #expect(viewModel.edit.media.count == 3)
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

    @Test func theCoverKeepsItsStyleWhenTheTypeChanges() async {
        let scenario = await makeScenario()
        scenario.viewModel.useFrameAsCover()
        let style = scenario.viewModel.edit.cover?.style
        scenario.viewModel.applyPreset(.soft, to: .allTexts)
        scenario.viewModel.applyPreset(.soft, to: .allCaptions)
        #expect(scenario.viewModel.edit.cover?.style == style)
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
