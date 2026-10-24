//
//  QuickEditMyCaptionStyleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The captions' "My style": saved from Caption style, put on every line in one undo step, and worn by new captions on a video
/// whose captions were never styled. It never carries the platform's safe margins.
@MainActor
@Suite("Quick edit My caption style")
struct QuickEditMyCaptionStyleTests {
    private func makeViewModel(styles: FakeTextStyleStore = FakeTextStyleStore()) async -> QuickEditViewModel {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: styles
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func savedOnceItGoesOnAnotherVideoInOneUndoStep() async {
        let styles = FakeTextStyleStore()
        let first = await makeViewModel(styles: styles)
        first.changeEdit { $0.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)] }
        first.captions.pickCaptionTheme(.pop)
        first.captions.saveMyCaptionStyle()
        #expect(styles.myCaptionStyle?.settings.theme == .pop)
        #expect(first.captions.captionsWearMyStyle)

        let second = await makeViewModel(styles: styles)
        second.changeEdit { $0.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)] }
        let margins = second.edit.captionCollection?.safeMargins
        #expect(!second.captions.captionsWearMyStyle)
        second.captions.applyMyCaptionStyle()
        #expect(second.edit.captionCollection?.theme == .pop)
        #expect(second.edit.captionCollection?.safeMargins == margins)
        #expect(second.captions.captionsWearMyStyle)
        second.undo()
        #expect(second.edit.captionCollection?.theme == .cue)
    }

    @Test func newCaptionsStartInItOnlyWhileNeverStyled() async {
        let styles = FakeTextStyleStore()
        var mine = CaptionSettings(theme: .editorial)
        mine.sizeScale = 1.2
        var saved = TakeEdit(sourceDuration: 20, aspect: .portrait)
        saved.captionCollection = mine
        styles.myCaptionStyle = MyCaptionStyle(of: saved)
        let viewModel = await makeViewModel(styles: styles)
        var snapshot = EditSnapshot(viewModel.edit)
        viewModel.captions.startsCaptionsInMyStyle(&snapshot)
        #expect(snapshot.captionCollection?.theme == .editorial)
        #expect(snapshot.captionCollection?.sizeScale == 1.2)

        viewModel.captions.pickCaptionTheme(.pop)
        var styled = EditSnapshot(viewModel.edit)
        viewModel.captions.startsCaptionsInMyStyle(&styled)
        #expect(styled.captionCollection?.theme == .pop)
    }
}
