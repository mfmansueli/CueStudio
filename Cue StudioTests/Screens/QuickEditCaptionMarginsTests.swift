//
//  QuickEditCaptionMarginsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The captions' safe margins go with the video's shape: Format, its Reset and Undo change them with it, and an edit saved before
/// they did opens put right (owner, 07/11/2026). The file's placement is `CaptionMarginsByFormatExportTests`.
@MainActor
@Suite("Quick edit caption margins by Format")
struct QuickEditCaptionMarginsTests {
    @Test func formatsResetAndUndoPutTheMarginsBackWithTheShape() async throws {
        let take = TestData.take(scriptID: nil, number: 1)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let portrait = CaptionSafeArea.margins(for: take, aspect: .portrait)
        let vertical = CaptionSafeArea.margins(for: take, aspect: .vertical)
        #expect(portrait != vertical)
        viewModel.look.setAspect(.vertical)
        #expect(viewModel.edit.captionCollection?.safeMargins == vertical)
        viewModel.undo()
        #expect(viewModel.edit.aspect == .portrait)
        #expect(viewModel.edit.captionCollection?.safeMargins == portrait)
        viewModel.redo()
        viewModel.look.resetFormat()
        #expect(viewModel.edit.captionCollection?.safeMargins == portrait)
    }

    @Test func anEditSavedWithTheRecordingsMarginsOnAnotherShapeOpensPutRight() {
        var take = TestData.take(scriptID: nil, number: 1)
        var saved = TakeEdit(sourceDuration: 30, aspect: .square)
        saved.captionCollection?.safeMargins = CaptionSafeArea.margins(for: take, aspect: .portrait)
        take.edit = saved
        #expect(QuickEditViewModel.startingEdit(for: take).captionCollection?.safeMargins == CaptionSafeArea.margins(for: take, aspect: .square))
        // Margins that aren't the recording's are a snapshot of their own and stay.
        let own = SafeZoneMargins(top: 3, bottom: 9, left: 4, right: 4)
        saved.captionCollection?.safeMargins = own
        take.edit = saved
        #expect(QuickEditViewModel.startingEdit(for: take).captionCollection?.safeMargins == own)
    }
}
