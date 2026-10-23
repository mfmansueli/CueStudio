//
//  QuickEditUndoPathTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The edit changes one way: every decision is an undo step, so an Undo elsewhere never takes back (or freezes) something
/// changed beside the history: the frame dragged on the preview, the captions switch, Lock and the captions' language. What
/// listening found stays through Undo.
@MainActor
@Suite("Quick edit: one way to change the edit")
struct QuickEditUndoPathTests {
    private func makeViewModel() async -> QuickEditViewModel {
        let take = TestData.take(scriptID: nil, number: 1)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func theFrameDraggedOnThePreviewIsOneUndoStep() async {
        let viewModel = await makeViewModel()
        viewModel.setAspect(.square)
        viewModel.beginCropMove()
        viewModel.moveCrop(to: 0.3)
        viewModel.moveCrop(to: 0.6)
        viewModel.moveCrop(to: 4)
        viewModel.endChange()
        #expect(viewModel.edit.cropOffset == 1)
        viewModel.undo()
        #expect(viewModel.edit.cropOffset == 0)
        #expect(viewModel.edit.aspect == .square)
        viewModel.redo()
        #expect(viewModel.edit.cropOffset == 1)
    }

    @Test func anUndoElsewhereNeverMovesTheFrameBack() async {
        let viewModel = await makeViewModel()
        viewModel.setAspect(.square)
        viewModel.perform(.addText(.title))
        viewModel.beginCropMove()
        viewModel.moveCrop(to: 0.5)
        viewModel.endChange()
        viewModel.undo()
        #expect(viewModel.edit.cropOffset == 0)
        #expect(viewModel.edit.texts.count == 1)
        viewModel.redo()
        viewModel.setCropFit(.fit)
        viewModel.undo()
        #expect(viewModel.edit.cropOffset == 0.5)
        #expect(viewModel.edit.cropFit == .fill)
    }

    @Test func followFaceStopsInTheSameStepAsTheDrag() async {
        let viewModel = await makeViewModel()
        viewModel.setAspect(.square)
        viewModel.setFollowsFace(true)
        viewModel.beginCropMove()
        #expect(viewModel.edit.faceFollow == nil)
        viewModel.moveCrop(to: -0.4)
        viewModel.endChange()
        viewModel.undo()
        #expect(viewModel.edit.faceFollow != nil)
        #expect(viewModel.edit.cropOffset == 0)
    }

    @Test func theCaptionsSwitchIsAnUndoStep() async {
        let viewModel = await makeViewModel()
        viewModel.changeEdit {
            $0.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)]
            $0.showsCaptions = true
        }
        viewModel.captions.toggleCaptions()
        #expect(!viewModel.edit.showsCaptions)
        viewModel.undo()
        #expect(viewModel.edit.showsCaptions)
        #expect(viewModel.edit.captions.count == 1)
    }

    @Test func lockingIsAnUndoStep() async throws {
        let viewModel = await makeViewModel()
        viewModel.perform(.addText(.title))
        let text = try #require(viewModel.edit.texts.first)
        viewModel.toggleLockOfSelection()
        #expect(viewModel.edit.lockedLayers == [text.id])
        viewModel.undo()
        #expect(viewModel.edit.lockedLayers.isEmpty)
        #expect(viewModel.edit.texts.count == 1)
        viewModel.redo()
        #expect(viewModel.edit.lockedLayers == [text.id])
    }

    @Test func theCaptionsLanguageIsAnUndoStep() async {
        let viewModel = await makeViewModel()
        viewModel.captions.setCaptionLanguage(.spanish)
        #expect(viewModel.edit.captionLanguage == .spanish)
        viewModel.undo()
        #expect(viewModel.edit.captionLanguage == nil)
    }

    @Test func whatListeningFoundStaysThroughUndo() async {
        let viewModel = await makeViewModel()
        viewModel.perform(.addText(.title))
        viewModel.updateFindings { $0.captionTranscript = CaptionTranscript(words: [], languageCode: "pt") }
        #expect(viewModel.canUndo)
        viewModel.undo()
        #expect(viewModel.edit.texts.isEmpty)
        #expect(viewModel.edit.captionTranscript?.languageCode == "pt")
    }
}
