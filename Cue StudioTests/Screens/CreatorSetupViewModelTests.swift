//
//  CreatorSetupViewModelTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@MainActor
@Suite("CreatorSetupViewModel")
struct CreatorSetupViewModelTests {
    private struct Scenario {
        let viewModel: CreatorSetupViewModel
        let preferences: PreferencesService
        let microphones: FakeMicrophones
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario() -> Scenario {
        let defaults = TestDefaults()
        let preferences = PreferencesService(defaults: defaults.defaults)
        let microphones = FakeMicrophones()
        let toast = ToastService()
        let viewModel = CreatorSetupViewModel(preferences: preferences, microphones: microphones, toast: toast)
        return Scenario(viewModel: viewModel, preferences: preferences, microphones: microphones, toast: toast, defaults: defaults)
    }

    @Test func recordingDefaultsAreSaved() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        viewModel.setFrontCamera(false)
        viewModel.setResolution(.uhd4K)
        viewModel.setFrameRate(.fps60)
        viewModel.setAspect(.square)
        let reloaded = PreferencesService(defaults: scenario.defaults.defaults).creatorSetup
        #expect(reloaded.lens == .wide)
        #expect(reloaded.resolution == .uhd4K)
        #expect(reloaded.frameRate == .fps60)
        #expect(reloaded.aspect == .square)
    }

    @Test func pickingAMicrophoneKeepsItsName() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.microphones.inputs = [FakeMicrophones.iPhone, FakeMicrophones.airPods]
        scenario.viewModel.selectMicrophone(FakeMicrophones.airPods)
        #expect(scenario.preferences.creatorSetup.microphone == .input(id: "airpods-pro", name: "AirPods Pro"))
        #expect(!scenario.viewModel.isPreferredMicrophoneMissing)
        scenario.viewModel.selectMicrophone(nil)
        #expect(scenario.preferences.creatorSetup.microphone == .automatic)
    }

    @Test func aSavedMicThatIsNotConnectedStaysTheChoice() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.selectMicrophone(FakeMicrophones.airPods)
        #expect(scenario.viewModel.isPreferredMicrophoneMissing)
        #expect(scenario.viewModel.microphoneDetail == "Not connected · takes use another mic until it's back")
        #expect(scenario.preferences.creatorSetup.microphone.name == "AirPods Pro")
    }

    @Test func textSizePresetsAndSlider() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        #expect(viewModel.textSizePreset == .medium)
        viewModel.setTextSize(.large)
        #expect(scenario.preferences.prompter.size == 36)
        viewModel.textSize = 40.4
        #expect(scenario.preferences.prompter.size == 40)
        #expect(viewModel.textSizePreset == nil)
        viewModel.textSize = 200
        #expect(scenario.preferences.prompter.size == PrompterSettings.sizeRange.upperBound)
    }

    @Test func speedIsKeptInTenths() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.speed = 1.04
        #expect(scenario.preferences.prompter.speed == 1)
        #expect(scenario.viewModel.speedDetail.hasSuffix("× · about 215 words a minute"))
    }

    @Test func theReadingLineMovesFromTheRecommendedSpot() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        #expect(viewModel.isReadingLineRecommended)
        viewModel.nudgeReadingLine(by: CreatorSetupViewModel.readingLineStep)
        #expect(scenario.preferences.prompter.readingLineOffset == 126)
        #expect(viewModel.readingLineSummary == "126 pt below the camera")
        viewModel.resetReadingLine()
        #expect(scenario.preferences.prompter.readingLineOffset == nil)
    }

    @Test func mirrorAndSafeZones() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.isMirrored = true
        scenario.viewModel.showsSafeZones = false
        #expect(scenario.preferences.prompter.isMirrored)
        #expect(!scenario.preferences.camera.showsSafeZones)
    }

    @Test func resetRestoresTheDefaultsOnly() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.preferences.creatorSetup = CreatorSetupTests.usual()
        scenario.preferences.camera.codec = .h264
        scenario.viewModel.reset()
        #expect(scenario.preferences.creatorSetup == CreatorSetup())
        #expect(scenario.preferences.camera.codec == .h264)
        #expect(scenario.toast.message == "Creator Setup is back to Cue's defaults")
    }
}
