//
//  PrompterViewModelLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The Selfie layout in `PrompterViewModel+Layout`: safe zone, reading line, text window, hidden
/// controls and "Reset to Recommended".
@MainActor
@Suite("PrompterViewModel layout")
struct PrompterViewModelLayoutTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let preferences: PreferencesService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(script: Script? = TestData.script(platform: .tiktok), defaults: TestDefaults = TestDefaults()) -> Scenario {
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        let toast = ToastService()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script?.id, mode: .selfie),
            library: library, takes: TakeLibraryService(repository: FakeTakeRepository()), preferences: preferences,
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(),
            camera: FakeCamera(), audio: FakeAudioMeter(), microphones: FakeMicrophones(), speech: FakeSpeechTranscriber(),
            languages: TestData.languages(defaults: defaults.defaults),
            remote: RemoteControlService(transport: FakeRemoteTransport()), toast: toast
        )
        return Scenario(viewModel: viewModel, preferences: preferences, toast: toast, defaults: defaults)
    }

    // MARK: - Hidden controls

    @Test func theEyeButtonHidesTheControlsUntilTheTakeStops() async {
        // Reels has no monetization minimum, so the second tap stops without a warning.
        let scenario = makeScenario(script: TestData.script(text: TestData.words(2000), platform: .reels))
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        viewModel.toggleControls()
        #expect(!viewModel.hidesControls)

        await viewModel.recordButtonTapped()
        #expect(viewModel.isRecording)
        #expect(!viewModel.hidesControls)
        #expect(viewModel.showsSafeZone)
        viewModel.toggleControls()
        #expect(viewModel.hidesControls)
        #expect(!viewModel.showsSafeZone)

        await viewModel.recordButtonTapped()
        #expect(!viewModel.isRecording)
        #expect(!viewModel.hidesControls)
        #expect(viewModel.showsSafeZone)
    }

    @Test func hideControlsWhileRecordingStartsTheTakeWithThemHidden() async {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(2000), platform: .reels))
        defer { scenario.defaults.tearDown() }
        scenario.preferences.prompter.hidesControlsWhileRecording = true
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.hidesControls)
        await scenario.viewModel.stopRecording()
        #expect(!scenario.viewModel.hidesControls)
    }

    // MARK: - Reading line

    @Test func draggingTheLineStoresItsDistanceFromTheLens() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.moveReadingLine(toY: 200)
        #expect(scenario.viewModel.session.prompter.readingLineOffset == 169)
        // A change for this take; Creator Setup keeps the recommended line.
        #expect(scenario.preferences.prompter.readingLineOffset == nil)
        #expect(scenario.viewModel.readingLayout.lineY == 200)
    }

    @Test func arrowsNudgeTheLineFromWhereItIs() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.nudgeReadingLine(by: ReadingLayout.nudge)
        #expect(scenario.viewModel.session.prompter.readingLineOffset == 126)
        scenario.viewModel.nudgeReadingLine(by: -2 * ReadingLayout.nudge)
        #expect(scenario.viewModel.session.prompter.readingLineOffset == 110)
    }

    @Test func theLineIsMeasuredFromThisDevicesLens() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.measured {
            $0.topInset = 20
            $0.topBarBottom = 64
        }
        #expect(scenario.viewModel.readingLayout.lensY == 10)
        #expect(scenario.viewModel.readingLayout.lineOffset == ReadingLayout.recommendedFrontOffset)
    }

    // MARK: - Reset

    @Test func resetBringsBackTheRecommendedLayout() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        viewModel.moveReadingLine(toY: 300)
        scenario.preferences.prompter.textWindowHeight = 200
        scenario.preferences.prompter.readingWidth = 0.6
        scenario.preferences.prompter.speed = 1.5
        scenario.preferences.prompter.hidesControlsWhileRecording = true
        scenario.preferences.camera.showsSafeZones = false
        viewModel.pickSafeZone(.custom)

        viewModel.resetLayout()

        let session = viewModel.session
        #expect(session.prompter.readingLineOffset == nil)
        #expect(scenario.preferences.prompter.textWindowHeight == 380)
        #expect(scenario.preferences.prompter.readingWidth == 0.93)
        #expect(session.prompter.speed == 0.7)
        #expect(!scenario.preferences.prompter.hidesControlsWhileRecording)
        #expect(session.camera.showsSafeZones)
        // Speed and safe zones are Creator Setup: the reset is for this session.
        #expect(scenario.preferences.prompter.speed == 1.5)
        #expect(!scenario.preferences.camera.showsSafeZones)
        #expect(viewModel.safeZone == .platform(.tiktok))
        #expect(scenario.toast.message == "Back to recommended layout")
    }

    // MARK: - Safe zone

    @Test func theSafeZoneFollowsTheScriptThenThePick() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        #expect(viewModel.safeZone == .platform(.tiktok))
        viewModel.pickSafeZone(.platform(.shorts))
        #expect(viewModel.safeZone == .platform(.shorts))

        let shorts = try #require(TestData.rules.safeZone(for: .shorts))
        let expected = viewModel.frameGeometry.toScreen(shorts.recommendedContentRect, in: shorts.videoSize)
        #expect(viewModel.safeZoneContentRect == expected)
    }

    @Test func freestyleShowsReelsSafeZone() {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.safeZone == .platform(.reels))
        #expect(scenario.viewModel.showsSafeZone)
    }

    @Test func horizontalVideoHasNoSafeZone() async {
        let scenario = makeScenario(script: TestData.script(platform: .youtube))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        // YouTube's 16:9 is recommended, not applied, until the creator accepts it.
        #expect(scenario.viewModel.safeZone != nil)
        scenario.viewModel.useRecommendedSetup()
        #expect(scenario.viewModel.safeZone == nil)
        #expect(!scenario.viewModel.showsSafeZone)
        #expect(scenario.viewModel.safeZoneOptions.isEmpty)
        await scenario.viewModel.disappear()
    }

    @Test func customSafeZoneUsesTheCreatorsMargins() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.pickSafeZone(.custom)
        scenario.preferences.prompter.customSafeZone = SafeZoneMargins(top: 10, bottom: 20, left: 5, right: 5)
        let frame = scenario.viewModel.frameGeometry.frameRect
        let content = scenario.viewModel.safeZoneContentRect
        #expect(content.map { abs($0.minY - (frame.minY + frame.height * 0.1)) < 0.01 } == true)
        #expect(content.map { abs(frame.maxY - $0.maxY - frame.height * 0.2) < 0.01 } == true)
    }

    // MARK: - Geometry

    @Test func overlaysFollowWhereThePreviewDrewTheImage() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let drawn = CGRect(x: 0, y: 50, width: 402, height: 402 * 16 / 9)
        scenario.viewModel.cameraImageMoved(to: drawn)
        #expect(scenario.viewModel.frameGeometry.sensorRect == drawn)
    }

    @Test func sheetsStopUnderTheTextWindowAsItWasWhenTheyOpened() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        let bottom = viewModel.readingLayout.windowRect.maxY
        viewModel.sheet = .display
        #expect(viewModel.sheetCeiling == bottom)
        scenario.preferences.prompter.textWindowHeight = 200
        #expect(viewModel.sheetCeiling == bottom)
        viewModel.sheet = nil
        viewModel.sheet = .display
        #expect(viewModel.sheetCeiling == viewModel.readingLayout.windowRect.maxY)
        #expect(viewModel.sheetCeiling != bottom)
    }

    @Test func freestyleSheetsHaveNoCeiling() {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.sheet = .camera
        #expect(scenario.viewModel.sheetCeiling == nil)
    }
}
