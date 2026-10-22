//
//  PrompterWatchTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The recorder driven from the wrist: each command changes what it would on the iPhone, and the watch hears the state it
/// led to, named as answered only once it happened (a take started, a take saved, or why not).
@MainActor
@Suite("Apple Watch and the recorder")
struct PrompterWatchTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let takes: TakeLibraryService
        let transport: InMemoryWatchTransport
        let watch: WatchLinkService
        let defaults: TestDefaults
    }

    private func makeScenario(mode: PrompterMode = .selfie, script: Bool = true) -> Scenario {
        let defaults = TestDefaults()
        let written = TestData.script(title: "Lançamento de outono", text: TestData.words(60))
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [written]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        let camera = FakeCamera()
        let transport = InMemoryWatchTransport()
        let watch = WatchLinkService(transport: transport)
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script ? written.id : nil, mode: mode),
            library: library, takes: takes, preferences: preferences, profile: CreatorProfileService(defaults: defaults.defaults),
            rules: TestData.rulesService(), camera: camera, audio: FakeAudioMeter(), microphones: FakeMicrophones(),
            speech: FakeSpeechTranscriber(), languages: TestData.languages(defaults: defaults.defaults),
            remote: RemoteControlService(transport: FakeRemoteTransport()), watch: watch, toast: ToastService(),
            recordingGrace: { {} }
        )
        return Scenario(viewModel: viewModel, camera: camera, takes: takes, transport: transport, watch: watch, defaults: defaults)
    }

    /// Sends `action` as the watch does; waits (up to 2 s) until the iPhone names it as answered.
    @discardableResult
    private func send(_ action: WatchAction, to scenario: Scenario) async -> WatchPhoneState {
        let command = WatchCommand(action: action)
        _ = scenario.transport.onCommand?(command)
        for _ in 0..<200 {
            if scenario.watch.lastState.answering == command.id { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return scenario.watch.lastState
    }

    @Test func withTheRecorderClosedTheWatchHearsThereIsNothingToRecord() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let answer = await send(.record, to: scenario)
        #expect(answer.phase == .noSession)
        #expect(scenario.camera.recordingsStarted == 0)
    }

    @Test func openingTheRecorderTellsTheWatchItIsReadyWithTheScript() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        let state = scenario.transport.sent.last
        #expect(state?.phase == .ready)
        #expect(state?.scriptTitle == "Lançamento de outono")
        await scenario.viewModel.disappear()
        #expect(scenario.transport.sent.last?.phase == .noSession)
    }

    @Test func recordThenEndSavesTheTakeAndTheWatchHearsItsNumberAndLength() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        let recording = await send(.record, to: scenario)
        #expect(recording.phase == .recording)
        #expect(recording.recordingStartedAt != nil)
        #expect(scenario.viewModel.isRecording)
        let saved = await send(.stop, to: scenario)
        #expect(saved.phase == .saved(take: 1, seconds: scenario.camera.clipDuration))
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.viewModel.reviewingTake != nil, "the review opens on the iPhone as after its own Stop")
    }

    @Test func recordAnotherFromASavedTakeStartsTheNextOne() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await send(.record, to: scenario)
        await send(.stop, to: scenario)
        let again = await send(.record, to: scenario)
        #expect(again.phase == .recording)
        #expect(scenario.viewModel.reviewingTake == nil)
        let saved = await send(.stop, to: scenario)
        #expect(saved.phase == .saved(take: 2, seconds: scenario.camera.clipDuration))
    }

    @Test func aTakeTheCameraCantStartIsSaidSo() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.camera.failsToRecord = true
        let answer = await send(.record, to: scenario)
        #expect(answer.phase == .failedStart)
        #expect(!scenario.viewModel.isRecording)
        let done = await send(.done, to: scenario)
        #expect(done.phase == .ready)
    }

    @Test func aRehearsalPlaysTheScriptWithoutRecording() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        let rehearsal = await send(.rehearse, to: scenario)
        #expect(rehearsal.phase == .rehearsal)
        #expect(rehearsal.isPlaying)
        #expect(!scenario.viewModel.isRecording)
        let paused = await send(.togglePlay, to: scenario)
        #expect(paused.phase == .rehearsal, "a paused rehearsal is still the rehearsal")
        #expect(!paused.isPlaying)
        let ended = await send(.endRehearsal, to: scenario)
        #expect(ended.phase == .ready)
    }

    @Test func theCrownsSpeedIsTheIPhonesSpeed() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        let faster = await send(.setSpeed(multiple: 1.4), to: scenario)
        #expect(faster.speedMultiple == 1.4)
        let slower = await send(.slower, to: scenario)
        #expect(slower.speedMultiple == 1.3)
    }

    @Test func studiosTeleprompterCantRecordFromTheWatch() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        let answer = await send(.record, to: scenario)
        #expect(answer.phase == .unavailable)
        #expect(scenario.camera.recordingsStarted == 0)
    }

    @Test func aFreestyleSessionRecordsWithoutAScript() async {
        let scenario = makeScenario(script: false)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.transport.sent.last?.scriptTitle == nil)
        let recording = await send(.record, to: scenario)
        #expect(recording.phase == .recording)
    }
}
