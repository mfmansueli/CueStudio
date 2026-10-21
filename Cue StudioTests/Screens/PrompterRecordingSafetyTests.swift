//
//  PrompterRecordingSafetyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Recording never loses a take: leaving the prompter mid-take (or while the take is starting) files it, a take the system
/// ends just as Stop comes is filed once, a take holds time in the background until it is filed, and a file the library
/// can't take in stays where it is (for `TakeRecovery`).
@MainActor
@Suite("Prompter recording safety")
struct PrompterRecordingSafetyTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let repository: FakeTakeRepository
        let takes: TakeLibraryService
        let toast: ToastService
        let grace: FakeApplicationGrace
        let defaults: TestDefaults
    }

    private func makeScenario() -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: TestData.words(60))
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let repository = FakeTakeRepository()
        let takes = TakeLibraryService(repository: repository)
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        let camera = FakeCamera()
        let toast = ToastService()
        let grace = FakeApplicationGrace()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script.id, mode: .selfie),
            library: library, takes: takes, preferences: preferences, profile: CreatorProfileService(defaults: defaults.defaults),
            rules: TestData.rulesService(), camera: camera, audio: FakeAudioMeter(), microphones: FakeMicrophones(),
            speech: FakeSpeechTranscriber(), languages: TestData.languages(defaults: defaults.defaults),
            remote: RemoteControlService(transport: FakeRemoteTransport()), toast: toast,
            recordingGrace: { grace.begin() }
        )
        return Scenario(
            viewModel: viewModel, camera: camera, repository: repository, takes: takes, toast: toast, grace: grace, defaults: defaults
        )
    }

    // MARK: - Leaving the prompter

    @Test func leavingMidTakeStopsItAndFilesItWithoutItsReview() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.isRecording)
        await scenario.viewModel.disappear()
        #expect(!scenario.viewModel.isRecording)
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.takes.takes.first?.duration == scenario.camera.clipDuration)
        #expect(scenario.viewModel.reviewingTake == nil, "the creator left: no review opens behind them")
        #expect(scenario.camera.stopCount >= 1)
    }

    @Test func leavingWhileTheTakeIsStartingStillFilesIt() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        // The creator closes the prompter while the camera is still starting the take: `disappear` finds nothing recording yet.
        let viewModel = scenario.viewModel
        scenario.camera.whileStarting = { await viewModel.disappear() }
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.camera.recordingsStarted == 1)
        #expect(!scenario.viewModel.isRecording, "nobody is left to stop it")
        #expect(!scenario.viewModel.isPlaying)
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.viewModel.reviewingTake == nil)
    }

    // MARK: - Ending on its own while stopping

    @Test func aTakeThatEndsOnItsOwnAsStopComesIsFiledOnce() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        scenario.camera.endsByItselfWhileStopping = .interrupted
        await scenario.viewModel.stopAnyway()
        #expect(scenario.takes.takes.count == 1, "one recording, one take")
        #expect(scenario.repository.storedFiles.count == 1)
        #expect(scenario.toast.message == "Interrupted · Take saved")
        #expect(scenario.viewModel.reviewingTake?.id == scenario.takes.takes.first?.id)
        #expect(!scenario.viewModel.isRecording)
    }

    // MARK: - Time in the background

    @Test func aTakeHoldsBackgroundTimeUntilItIsFiled() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(!scenario.grace.isHeld)
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.grace.isHeld, "going to the background mid-take, Cue must still hear that it ended, and file it")
        await scenario.viewModel.stopAnyway()
        #expect(!scenario.grace.isHeld)
        #expect(scenario.grace.begun == 1 && scenario.grace.ended == 1)
        #expect(scenario.takes.takes.count == 1)
    }

    @Test func aTakeTheBackgroundEndedIsFiledAndGivesTheTimeBack() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        // Going to the background interrupts the capture session: the movie output ends the take, its file finished.
        let clip = RecordedClip(url: URL.temporaryDirectory.appending(path: "away-\(UUID().uuidString).mov"), duration: 9)
        scenario.camera.onRecordingEnded?(clip, .interrupted)
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.toast.message == "Interrupted · Take saved")
        #expect(!scenario.grace.isHeld)
    }

    @Test func aTakeThatFailsToStartHoldsNoBackgroundTime() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.camera.failsToRecord = true
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.grace.begun == 0)
        #expect(!scenario.viewModel.isRecording)
    }

    // MARK: - A library that can't take the file in

    @Test func aTakeTheLibraryCantStoreKeepsItsFileAndSaysSo() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let url = URL.temporaryDirectory.appending(path: "\(TakeRecovery.prefix)\(UUID().uuidString).mov")
        try Data("a recording".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        scenario.camera.clipURL = url
        scenario.repository.failsToStore = true
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.stopAnyway()
        #expect(scenario.takes.takes.isEmpty)
        #expect(scenario.toast.message == "The take couldn't be saved")
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), "the recording is still there for the next launch")
        #expect(!scenario.grace.isHeld)
    }
}
