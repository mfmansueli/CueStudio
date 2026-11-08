//
//  QuickEditMixLevelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Volume says when the edit's sounds together go over full scale: the preview may distort there, the exported video doesn't
/// (`QuickEditViewModel.measureMix`, matrix 10.3).
@MainActor
struct QuickEditMixLevelTests {
    private func makeViewModel(peak: Float?) async -> (QuickEditViewModel, FakeTakeEditor) {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 12
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.mixPeak = peak
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback()
        )
        await viewModel.prepare()
        return (viewModel, editor)
    }

    @Test func aMixOverFullScaleIsTold() async {
        let (viewModel, editor) = await makeViewModel(peak: 1.36)
        await viewModel.measureMix()
        #expect(viewModel.mixTooLoud)
        #expect(editor.mixPeakRequests == 1)
    }

    @Test func aMixUnderFullScaleOrOneSoundSaysNothing() async {
        let (loud, _) = await makeViewModel(peak: 0.95)
        await loud.measureMix()
        #expect(!loud.mixTooLoud)
        let (single, _) = await makeViewModel(peak: nil)
        await single.measureMix()
        #expect(!single.mixTooLoud)
    }

    /// A slider still moving measures once it rests: a measurement cancelled on the way asks for nothing.
    @Test func aCancelledMeasurementAsksForNothing() async {
        let (viewModel, editor) = await makeViewModel(peak: 1.36)
        let task = Task { await viewModel.measureMix() }
        task.cancel()
        await task.value
        #expect(editor.mixPeakRequests == 0)
        #expect(!viewModel.mixTooLoud)
    }
}
