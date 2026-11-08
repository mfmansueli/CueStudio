//
//  QuickEditPhraseZoomTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Captions › Select › Zoom: a zoom from the picked lines, lines said back to back as one phrase, one undo step, and on its own
/// afterwards: correcting, splitting or deleting the line leaves it.
@MainActor
struct QuickEditPhraseZoomTests {
    private let first = CaptionCue(text: "this is the part", start: 1, end: 2, origin: .manual)
    private let second = CaptionCue(text: "that really matters", start: 2.1, end: 3, origin: .manual)
    private let later = CaptionCue(text: "and much later on", start: 8, end: 9, origin: .manual)

    private func makeViewModel() async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit {
            $0.captions = [first, second, later]
            $0.showsCaptions = true
        }
        return viewModel
    }

    @Test func linesSaidBackToBackZoomAsOnePhraseOneStep() async throws {
        let viewModel = await makeViewModel()
        viewModel.captions.startPickingCaptions(with: first.id)
        viewModel.captions.toggleCaptionPick(second.id)
        viewModel.captions.toggleCaptionPick(later.id)
        #expect(viewModel.captions.pickedPhraseZoom == nil)
        let steps = viewModel.document.history.past.count
        viewModel.captions.setPickedCaptionsZoom(.strong)
        #expect(viewModel.edit.phraseZooms.count == 2)
        #expect(viewModel.edit.phraseZooms.first?.span == TimeSpan(start: 1, end: 3))
        #expect(viewModel.captions.pickedPhraseZoom == .strong)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.edit.timeline.segments.count == 1, "The clip isn’t split")

        viewModel.captions.setPickedCaptionsZoom(nil)
        #expect(viewModel.edit.phraseZooms.isEmpty)
        viewModel.undo()
        #expect(viewModel.edit.phraseZooms.count == 2)
    }

    @Test func itStaysWhenTheLineIsCorrectedOrDeleted() async throws {
        let viewModel = await makeViewModel()
        viewModel.captions.startPickingCaptions(with: later.id)
        viewModel.captions.setPickedCaptionsZoom(.medium)
        viewModel.captions.stopPickingCaptions()
        let zoom = try #require(viewModel.edit.phraseZooms.first)
        viewModel.captions.setCaptionText(later.id, "and much, much later on")
        #expect(viewModel.edit.phraseZooms == [zoom])
        #expect(viewModel.captions.phraseZoom(onLine: later.id) == zoom)
        viewModel.changeEdit { $0.captions.removeAll { $0.id == later.id } }
        #expect(viewModel.edit.phraseZooms == [zoom])
    }
}
