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

    /// A freeze, a reverse or an import still running would land under the narration: Record waits for it, and says so.
    @Test func recordWaitsForWorkStillRunning() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.isImportingMedia = true
        await viewModel.audio.startVoiceOver()
        #expect(!viewModel.audio.isRecordingVoiceOver)
        #expect(viewModel.toast.message == "Still working · Record when it finishes")
        viewModel.isImportingMedia = false
        await viewModel.audio.startVoiceOver()
        #expect(viewModel.audio.isRecordingVoiceOver)
    }

    /// The narration stays where it was recorded over, even if a change lands during the take, and no tool reaches the edit
    /// while it records.
    @Test func aNarrationKeepsThePlaceItStartedAt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.player.seek(to: 5)
        await viewModel.audio.startVoiceOver()
        viewModel.perform(.splitClip)
        #expect(viewModel.edit.timeline.segments.count == 1)
        // A change that lands anyway (a job started before Record): the clip plays twice as fast.
        viewModel.updateClip { $0.speed = 2 }
        viewModel.audio.stopVoiceOver()
        #expect(viewModel.edit.voiceOvers.first.map { abs($0.anchor - 5) < 0.000_1 } == true)
    }

    @Test func aCallKeepsWhatWasRecorded() async {
        let scenario = await makeScenario()
        await scenario.viewModel.audio.startVoiceOver()
        #expect(scenario.viewModel.audio.isRecordingVoiceOver)
        scenario.recorder.stopOnItsOwn(.interrupted)
        #expect(!scenario.viewModel.audio.isRecordingVoiceOver)
        #expect(scenario.viewModel.edit.voiceOvers.count == 1)
        #expect(scenario.viewModel.toast.message == "Recording stopped · Another app took the microphone")
    }

    @Test func aFileThatCantBeWrittenIsDroppedAndSaid() async {
        let scenario = await makeScenario()
        var failures: [EditorFailureReport] = []
        scenario.viewModel.reportFailure = { failures.append($0) }
        await scenario.viewModel.audio.startVoiceOver()
        scenario.recorder.stopOnItsOwn(.failed)
        #expect(!scenario.viewModel.audio.isRecordingVoiceOver)
        #expect(scenario.recorder.cancelled)
        #expect(scenario.viewModel.edit.voiceOvers.isEmpty)
        #expect(scenario.viewModel.toast.message == "Couldn't record the voice-over · Try again")
        #expect(failures.map(\.operation) == ["voiceOverRecord"])
    }

    @Test func theVideoStoppingStopsTheNarrationAndKeepsIt() async throws {
        let scenario = await makeScenario()
        let player = try #require(scenario.viewModel.player as? FakeEditPlayback)
        await scenario.viewModel.audio.startVoiceOver()
        #expect(player.isPlaying)
        player.playToTheEnd()
        #expect(!scenario.viewModel.audio.isRecordingVoiceOver)
        #expect(scenario.viewModel.edit.voiceOvers.count == 1)
        // Pause does it too.
        await scenario.viewModel.audio.startVoiceOver()
        scenario.viewModel.togglePlayback()
        #expect(!scenario.viewModel.audio.isRecordingVoiceOver)
        #expect(scenario.viewModel.edit.voiceOvers.count == 2)
    }

    @Test func stopAddsTheNarrationOnce() async {
        let scenario = await makeScenario()
        await scenario.viewModel.audio.startVoiceOver()
        scenario.viewModel.audio.stopVoiceOver()
        #expect(scenario.viewModel.edit.voiceOvers.count == 1)
        #expect(!scenario.viewModel.audio.isRecordingVoiceOver)
    }

    @Test func leavingWhileRecordingKeepsTheNarrationInTheDraft() async throws {
        let scenario = await makeScenario()
        await scenario.viewModel.audio.startVoiceOver()
        scenario.viewModel.cancel()
        #expect(!scenario.recorder.cancelled)
        let draft = try #require(scenario.drafts.drafts.values.first)
        #expect(draft.edit.voiceOvers.count == 1)
    }
}
