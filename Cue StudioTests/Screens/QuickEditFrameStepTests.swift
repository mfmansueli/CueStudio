//
//  QuickEditFrameStepTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// ‹ › beside Play: one frame back or forward, paused, from the frame the playhead is on, never past the ends.
@MainActor
@Suite("Quick edit frame step")
struct QuickEditFrameStepTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    @Test func aStepIsOneFrameFromTheFrameThePlayheadIsOn() async {
        let (viewModel, player) = await makeViewModel()
        let frame = 1 / viewModel.frameRate
        player.currentTime = 5 + frame * 0.4
        viewModel.stepFrame(1)
        #expect(abs(player.currentTime - (5 + frame)) < 0.000_1)
        viewModel.stepFrame(-1)
        viewModel.stepFrame(-1)
        #expect(abs(player.currentTime - (5 - frame)) < 0.000_1)
        #expect(!player.isPlaying)
    }

    @Test func itStopsAtTheEnds() async {
        let (viewModel, player) = await makeViewModel()
        player.currentTime = 0
        viewModel.stepFrame(-1)
        #expect(player.currentTime == 0)
        player.currentTime = viewModel.edit.editedDuration
        viewModel.stepFrame(1)
        #expect(player.currentTime == viewModel.edit.editedDuration)
    }
}
