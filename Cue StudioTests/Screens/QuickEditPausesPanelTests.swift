//
//  QuickEditPausesPanelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Pauses on the design's demo take: four pauses marked to go, the time they save, one kept, the
/// rest removed in one undo step, and "Pauses longer than".
@MainActor
@Suite("Quick edit pauses panel")
struct QuickEditPausesPanelTests {
    private func makeViewModel() async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = SampleEdit.duration
        take.edit = SampleEdit.make(aspect: take.aspect)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = SampleEdit.duration
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.panel = .pauses
        return viewModel
    }

    @Test func everyPauseStartsMarkedWithTheTimeItSaves() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.pauseCandidates.count == 4)
        #expect(viewModel.markedCleanUp.count == 4)
        #expect(viewModel.cleanUpApplyLabel == "Remove 4 pauses")
        // 0.96 + 0.86 + 1.36 + 0.88 s.
        #expect(viewModel.cleanUpSavingLabel == "−\(TestData.decimal("4.1"))s")
        #expect(viewModel.cleanUpResultLabel == "00:21.6 → 00:17.5")
    }

    @Test func oneKeptTheOthersRemovedInOneStep() async {
        let viewModel = await makeViewModel()
        let kept = viewModel.pauseCandidates[1]
        viewModel.tapCleanUpCard(kept.id)
        #expect(!viewModel.isMarked(kept))
        #expect(viewModel.cleanUpApplyLabel == "Remove 3 pauses")
        let steps = viewModel.history.past.count
        viewModel.applyCleanUp()
        #expect(abs(viewModel.edit.editedDuration - 18.4) < 0.001)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(viewModel.panel == nil)
        // The kept one stays listed next time; the removed ones are gone from the edit.
        #expect(viewModel.edit.suggestions.first { $0.id == kept.id }?.status == .kept)
        viewModel.undo()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
    }

    @Test func aLongerThresholdListsFewerPauses() async {
        let viewModel = await makeViewModel()
        // 1.2, 1.1, 1.6 and 1.12 s of silence.
        for _ in 0..<5 { viewModel.raisePauseThreshold() }
        #expect(abs(viewModel.pauseThreshold - 1.2) < 0.001)
        #expect(viewModel.pauseCandidates.count == 2)
        viewModel.lowerPauseThreshold()
        #expect(viewModel.pauseCandidates.count == 4)
        for _ in 0..<10 { viewModel.lowerPauseThreshold() }
        #expect(abs(viewModel.pauseThreshold - QuickEditViewModel.pauseThresholdRange.lowerBound) < 0.001)
        #expect(viewModel.pauseCandidates.count == 4)
    }

    @Test func nothingMarkedRemovesNothing() async {
        let viewModel = await makeViewModel()
        for pause in viewModel.pauseCandidates { viewModel.toggleMark(pause.id) }
        #expect(viewModel.cleanUpApplyLabel == "Nothing selected")
        viewModel.applyCleanUp()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
    }
}
