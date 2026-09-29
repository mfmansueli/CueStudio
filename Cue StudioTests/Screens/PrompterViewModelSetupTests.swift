//
//  PrompterViewModelSetupTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Creator Setup in the recording pipeline (`PrompterViewModel+Setup`): defaults, platform
/// recommendations, changes for one take, a missing mic and the remote.
@MainActor
@Suite("PrompterViewModel setup")
struct PrompterViewModelSetupTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let microphones: FakeMicrophones
        let transport: FakeRemoteTransport
        let remote: RemoteControlService
        let preferences: PreferencesService
        let takes: TakeLibraryService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(
        script: Script? = TestData.script(text: TestData.words(2000), platform: .tiktok),
        mode: PrompterMode = .selfie,
        setup: CreatorSetup = CreatorSetupTests.usual()
    ) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.creatorSetup = setup
        preferences.camera.countdown = .off
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.monetizationGoals = false
        let camera = FakeCamera()
        let microphones = FakeMicrophones()
        microphones.inputs = [FakeMicrophones.iPhone, FakeMicrophones.airPods]
        let transport = FakeRemoteTransport()
        let remote = RemoteControlService(transport: transport, makeCode: { "ABC234" })
        let toast = ToastService()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script?.id, mode: mode),
            library: library, takes: takes, preferences: preferences, profile: profile, rules: TestData.rulesService(),
            camera: camera, audio: FakeAudioMeter(), microphones: microphones, speech: FakeSpeechTranscriber(),
            languages: TestData.languages(defaults: defaults.defaults),
            remote: remote, toast: toast
        )
        return Scenario(
            viewModel: viewModel, camera: camera, microphones: microphones, transport: transport, remote: remote,
            preferences: preferences, takes: takes, toast: toast, defaults: defaults
        )
    }

    // MARK: - Creator defaults

    /// Test 2: a new recording starts from the Creator Setup.
    @Test func aNewRecordingStartsFromTheCreatorSetup() async {
        let scenario = makeScenario(setup: {
            var setup = CreatorSetupTests.usual()
            setup.resolution = .hd1080
            return setup
        }())
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        let started = scenario.camera.startedSettings.last
        #expect(started?.lens == .front)
        #expect(started?.microphoneID == "airpods-pro")
        #expect(started?.aspect == .portrait)
        #expect(scenario.viewModel.session.prompter.size == 36)
        #expect(scenario.viewModel.session.prompter.speed == 1.2)
        #expect(!scenario.viewModel.showsRecommendation)
        #expect(scenario.viewModel.captureSummary == "1080p · 9:16")
        await scenario.viewModel.disappear()
    }

    @Test func freestyleUsesTheCreatorSetupWithoutARecommendation() async {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.camera.startedSettings.last?.resolution == .uhd4K)
        #expect(scenario.viewModel.session.recommendation == nil)
        #expect(!scenario.viewModel.showsRecommendation)
        await scenario.viewModel.disappear()
    }

    // MARK: - Recommendations

    /// Test 3: 4K by default, 1080p recommended for TikTok: the conflict is shown.
    @Test func aConflictingRecommendationIsShown() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.viewModel.showsRecommendation)
        #expect(scenario.viewModel.session.conflicts == [SetupConflict(field: .quality, recommended: "1080p", usual: "4K")])
        #expect(scenario.viewModel.session.recommendation?.title == "Recommended for TikTok")
        // Shown, not applied.
        #expect(scenario.camera.startedSettings.last?.resolution == .uhd4K)
        await scenario.viewModel.disappear()
    }

    /// Test 4: Use Recommended → this session in 1080p; the default stays 4K.
    @Test func useRecommendedChangesThisSessionOnly() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.useRecommendedSetup()
        #expect(scenario.viewModel.session.camera.resolution == .hd1080)
        #expect(scenario.preferences.camera.resolution == .uhd4K)
        #expect(PreferencesService(defaults: scenario.defaults.defaults).camera.resolution == .uhd4K)
        #expect(scenario.viewModel.session.captureSource == .recommended(.tiktok))
        #expect(!scenario.viewModel.showsRecommendation)
        #expect(scenario.toast.message == "TikTok setup for this video")

        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.camera.recordedSettings.last?.resolution == .hd1080)
        await scenario.viewModel.stopRecording(openReview: false)
        #expect(scenario.takes.takes.first?.resolution == .hd1080)
        await scenario.viewModel.disappear()
    }

    /// Test 5: Keep My Setup → this session in 4K.
    @Test func keepMySetupRecordsWithTheCreatorSetup() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.keepCreatorSetup()
        #expect(scenario.viewModel.session.camera.resolution == .uhd4K)
        #expect(!scenario.viewModel.showsRecommendation)
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.camera.recordedSettings.last?.resolution == .uhd4K)
        await scenario.viewModel.disappear()
    }

    @Test func recordingWithoutAnsweringKeepsTheCreatorSetup() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.camera.recordedSettings.last?.resolution == .uhd4K)
        #expect(scenario.viewModel.session.choice == .keepCreatorSetup)
        await scenario.viewModel.stopRecording(openReview: false)
        #expect(!scenario.viewModel.showsRecommendation)
        await scenario.viewModel.disappear()
    }

    /// Test 6: Front by default; the creator flips to the back camera and back to front for this
    /// video: the session and the default are both front.
    @Test func manualChangesAreForThisTakeOnly() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.flipCamera()
        #expect(scenario.viewModel.session.camera.lens == .wide)
        #expect(scenario.viewModel.session.source(of: .camera) == .thisTake)
        #expect(scenario.preferences.camera.lens == .front)
        scenario.viewModel.flipCamera()
        #expect(scenario.viewModel.session.camera.lens == .front)
        #expect(scenario.viewModel.session.source(of: .camera) == .creatorSetup)
        #expect(scenario.preferences.camera.lens == .front)
        await scenario.viewModel.disappear()
    }

    @Test func backToMySetupDropsTheSessionsChanges() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.useRecommendedSetup()
        scenario.viewModel.cycleAspect()
        scenario.viewModel.setSpeed(1.8)
        scenario.viewModel.backToCreatorSetup()
        #expect(scenario.viewModel.session.current == scenario.preferences.creatorSetup)
        await scenario.viewModel.disappear()
    }

    @Test func theSetupPillOpensThisTakeButNotWhileRecording() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.openRecordingSetup()
        #expect(scenario.viewModel.sheet == .recordingSetup)
        scenario.viewModel.sheet = nil
        await scenario.viewModel.recordButtonTapped()
        scenario.viewModel.openRecordingSetup()
        #expect(scenario.viewModel.sheet == nil)
        await scenario.viewModel.disappear()
    }

    // MARK: - Fallbacks

    /// Test 7: AirPods saved, AirPods gone: the take still records, with a quiet notice.
    @Test func aMissingMicrophoneFallsBackWithANotice() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.microphones.inputs = [FakeMicrophones.iPhone]
        await scenario.viewModel.appear()
        #expect(scenario.toast.message == "AirPods Pro unavailable · Using iPhone Microphone instead")
        scenario.toast.dismiss()
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.isRecording)
        // Once is enough.
        #expect(scenario.toast.message == nil)
        await scenario.viewModel.disappear()
    }

    @Test func aConnectedMicrophoneNeedsNoNotice() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.toast.message == nil)
        await scenario.viewModel.disappear()
    }

    @Test func aMissingCameraFallsBackWithANotice() async {
        let scenario = makeScenario(setup: {
            var setup = CreatorSetup()
            setup.lens = .telephoto
            return setup
        }())
        defer { scenario.defaults.tearDown() }
        scenario.camera.missingLenses = [.telephoto]
        await scenario.viewModel.appear()
        #expect(scenario.toast.message == "Back · Telephoto unavailable · Using Front instead")
        await scenario.viewModel.disappear()
    }

    // MARK: - Remote

    @Test func theRemoteDrivesTheText() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.remote.startHosting()
        scenario.transport.emit(.connected(deviceName: "iPad"))
        await scenario.viewModel.appear()

        scenario.transport.emit(.received(.command(.togglePlay)))
        #expect(scenario.viewModel.isPlaying)
        scenario.transport.emit(.received(.command(.faster)))
        #expect(scenario.viewModel.session.prompter.speed == 1.3)
        scenario.transport.emit(.received(.command(.slower)))
        scenario.transport.emit(.received(.command(.slower)))
        #expect(scenario.viewModel.session.prompter.speed == 1.1)
        scenario.transport.emit(.received(.command(.pause)))
        #expect(!scenario.viewModel.isPlaying)

        let last = scenario.transport.sentStatuses.last
        #expect(last?.scriptTitle == "Test script")
        #expect(last?.isPlaying == false)
        #expect(last?.speed == 1.1)
        // Speed from the remote is for this session too.
        #expect(scenario.preferences.prompter.speed == 1.2)

        await scenario.viewModel.disappear()
        #expect(scenario.transport.sentStatuses.last == .idle)
    }

    @Test func theRemoteSheetOpensFromThePrompter() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.openRemoteControl()
        #expect(scenario.viewModel.sheet == .remote)
    }
}
