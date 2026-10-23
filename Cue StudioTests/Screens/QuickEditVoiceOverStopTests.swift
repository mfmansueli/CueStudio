//
//  QuickEditVoiceOverStopTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A narration that stops without Stop never leaves the screen recording: the video stopping under it (its end, Pause) or a
/// call or another app taking the microphone keeps what was recorded (and says why); a file that can't be written is dropped
/// and said. Leaving the editor while recording keeps the narration in the draft.
@MainActor
@Suite("Quick edit: a voice-over stopping on its own")
struct QuickEditVoiceOverStopTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let recorder: FakeVoiceRecorder
        let drafts: FakeDraftStore
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let recorder = FakeVoiceRecorder()
        let drafts = FakeDraftStore()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: drafts, toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: recorder, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, recorder: recorder, drafts: drafts)
    }

    @Test func aCallKeepsWhatWasRecorded() async {
        let scenario = await makeScenario()
        await scenario.viewModel.startVoiceOver()
        #expect(scenario.viewModel.isRecordingVoiceOver)
        scenario.recorder.stopOnItsOwn(.interrupted)
        #expect(!scenario.viewModel.isRecordingVoiceOver)
        #expect(scenario.viewModel.edit.voiceOvers.count == 1)
        #expect(scenario.viewModel.toast.message == "Recording stopped · Another app took the microphone")
    }

    @Test func aFileThatCantBeWrittenIsDroppedAndSaid() async {
        let scenario = await makeScenario()
        var failures: [EditorFailureReport] = []
        scenario.viewModel.reportFailure = { failures.append($0) }
        await scenario.viewModel.startVoiceOver()
        scenario.recorder.stopOnItsOwn(.failed)
        #expect(!scenario.viewModel.isRecordingVoiceOver)
        #expect(scenario.recorder.cancelled)
        #expect(scenario.viewModel.edit.voiceOvers.isEmpty)
        #expect(scenario.viewModel.toast.message == "Couldn't record the voice-over · Try again")
        #expect(failures.map(\.operation) == ["voiceOverRecord"])
    }

    @Test func theVideoStoppingStopsTheNarrationAndKeepsIt() async throws {
        let scenario = await makeScenario()
        let player = try #require(scenario.viewModel.player as? FakeEditPlayback)
        await scenario.viewModel.startVoiceOver()
        #expect(player.isPlaying)
        player.playToTheEnd()
        #expect(!scenario.viewModel.isRecordingVoiceOver)
        #expect(scenario.viewModel.edit.voiceOvers.count == 1)
        // Pause does it too.
        await scenario.viewModel.startVoiceOver()
        scenario.viewModel.togglePlayback()
        #expect(!scenario.viewModel.isRecordingVoiceOver)
        #expect(scenario.viewModel.edit.voiceOvers.count == 2)
    }

    @Test func stopAddsTheNarrationOnce() async {
        let scenario = await makeScenario()
        await scenario.viewModel.startVoiceOver()
        scenario.viewModel.stopVoiceOver()
        #expect(scenario.viewModel.edit.voiceOvers.count == 1)
        #expect(!scenario.viewModel.isRecordingVoiceOver)
    }

    @Test func leavingWhileRecordingKeepsTheNarrationInTheDraft() async throws {
        let scenario = await makeScenario()
        await scenario.viewModel.startVoiceOver()
        scenario.viewModel.cancel()
        #expect(!scenario.recorder.cancelled)
        let draft = try #require(scenario.drafts.drafts.values.first)
        #expect(draft.edit.voiceOvers.count == 1)
    }
}
