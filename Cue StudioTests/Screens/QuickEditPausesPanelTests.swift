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
        #expect(viewModel.clips.pauseCandidates.count == 4)
        #expect(viewModel.clips.markedCleanUp.count == 4)
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove 4 pauses")
        // 0.96 + 0.86 + 1.36 + 0.88 s.
        #expect(viewModel.clips.cleanUpSavingLabel == "−\(TestData.decimal("4.1"))s")
        #expect(viewModel.clips.cleanUpResultLabel == "00:21.6 → 00:17.5")
    }

    @Test func oneKeptTheOthersRemovedInOneStep() async {
        let viewModel = await makeViewModel()
        let kept = viewModel.clips.pauseCandidates[1]
        viewModel.clips.tapCleanUpCard(kept.id)
        #expect(!viewModel.clips.isMarked(kept))
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove 3 pauses")
        let steps = viewModel.document.history.past.count
        viewModel.clips.applyCleanUp()
        #expect(abs(viewModel.edit.editedDuration - 18.4) < 0.001)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.panel == nil)
        // The kept one stays listed next time; the removed ones are gone from the edit.
        #expect(viewModel.edit.suggestions.first { $0.id == kept.id }?.status == .kept)
        viewModel.undo()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
    }

    @Test func aLongerThresholdListsFewerPauses() async {
        let viewModel = await makeViewModel()
        // 1.2, 1.1, 1.6 and 1.12 s of silence.
        for _ in 0..<5 { viewModel.clips.raisePauseThreshold() }
        #expect(abs(viewModel.clips.pauseThreshold - 1.2) < 0.001)
        #expect(viewModel.clips.pauseCandidates.count == 2)
        viewModel.clips.lowerPauseThreshold()
        #expect(viewModel.clips.pauseCandidates.count == 4)
        for _ in 0..<10 { viewModel.clips.lowerPauseThreshold() }
        #expect(abs(viewModel.clips.pauseThreshold - ClipsViewModel.pauseThresholdRange.lowerBound) < 0.001)
        #expect(viewModel.clips.pauseCandidates.count == 4)
    }

    @Test func nothingMarkedRemovesNothing() async {
        let viewModel = await makeViewModel()
        for pause in viewModel.clips.pauseCandidates { viewModel.clips.toggleMark(pause.id) }
        #expect(viewModel.clips.cleanUpApplyLabel == "Nothing selected")
        viewModel.clips.applyCleanUp()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
    }
}
