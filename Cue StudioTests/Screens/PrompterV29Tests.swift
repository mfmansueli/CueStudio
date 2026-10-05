//
//  PrompterV29Tests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The v29 recorder (5.2): the box that shrinks while recording, the pinch on the right edge, Studio as a prompter only (v30) and what
/// happens when a take ends on its own (04 · F3).
@MainActor
@Suite("Recorder v29")
struct PrompterV29Tests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let takes: TakeLibraryService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(mode: PrompterMode = .selfie) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: TestData.words(60))
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        let camera = FakeCamera()
        let toast = ToastService()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script.id, mode: mode),
            library: library, takes: takes, preferences: preferences, profile: CreatorProfileService(defaults: defaults.defaults),
            rules: TestData.rulesService(), camera: camera, audio: FakeAudioMeter(), microphones: FakeMicrophones(),
            speech: FakeSpeechTranscriber(), languages: TestData.languages(defaults: defaults.defaults),
            remote: RemoteControlService(transport: FakeRemoteTransport()), toast: toast
        )
        return Scenario(viewModel: viewModel, camera: camera, takes: takes, toast: toast, defaults: defaults)
    }

    // MARK: - The box

    private let metrics = SelfieScreenMetrics()

    private func layout(isRecording: Bool) -> ReadingLayout {
        let frame = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: metrics.screen), aspect: .portrait, resolution: .hd1080).frameRect
        return ReadingLayout(
            metrics: metrics, isFrontCamera: true, frameRect: frame, lineOffset: nil, windowHeight: 300, readingWidth: 0.9,
            isRecording: isRecording
        )
    }

    @Test func theBoxShrinksWhileRecording() {
        let idle = layout(isRecording: false).windowRect
        let recording = layout(isRecording: true).windowRect
        #expect(recording.width == idle.width - 20)
        #expect(recording.height == (300 * 0.84).rounded())
        #expect(recording.minX == idle.minX + 10)
    }

    @Test func theLineDoesNotMoveWhenTheBoxShrinks() {
        #expect(layout(isRecording: true).lineY == layout(isRecording: false).lineY)
    }

    // MARK: - The pinch

    @Test func aPinchMovesTheLineByAFractionOfTheScreenAndStaysBetweenTenAndFiftyPercent() {
        #expect(ReadingLinePinch.fraction(from: 0.2, magnification: 1) == 0.2)
        #expect(abs(ReadingLinePinch.fraction(from: 0.2, magnification: 1.5) - 0.375) < 0.0001)
        #expect(ReadingLinePinch.fraction(from: 0.2, magnification: 4) == 0.5)
        #expect(ReadingLinePinch.fraction(from: 0.2, magnification: 0.1) == 0.1)
    }

    @Test func thePinchWritesTheLineIntoTheSessionSettings() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.measured { $0.screen = CGSize(width: 402, height: 874); $0.topBarBottom = 100; $0.toolbarTop = 640 }
        scenario.viewModel.moveReadingLine(toFraction: 0.3)
        #expect(scenario.viewModel.session.prompter.readingLineOffset != nil)
        #expect(abs(scenario.viewModel.readingLineFraction - 0.3) < 0.01)
    }

    // MARK: - Compact

    @Test func theCompactBarIsRecordingAndNotPeeking() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.isCompact)
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.isRecording && scenario.viewModel.isCompact)
        scenario.viewModel.bar.expand()
        #expect(!scenario.viewModel.isCompact)
    }

    // MARK: - Studio

    @Test func studioNeverStartsTheCameraAndSelfieGetsItBack() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.camera.startCount == 0, "Studio is only the prompter: no camera")
        #expect(scenario.camera.stopCount == 1)
        await scenario.viewModel.switchMode(to: .selfie)
        #expect(scenario.camera.startedSettings.last?.lens == .front)
        #expect(scenario.viewModel.session.camera.lens == .front)
        await scenario.viewModel.switchMode(to: .studio)
        #expect(scenario.viewModel.session.camera.lens == .front, "the lens is never touched")
    }

    @Test func studioHasNothingToRecord() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.camera.status = .unavailable
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        #expect(!scenario.viewModel.isRecording)
        #expect(scenario.takes.takes.isEmpty)
    }

    @Test func playFromTheTopInStudioCountsDownFirstAndATapCancelsIt() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.session.camera.countdown = .three
        scenario.viewModel.togglePlay()
        #expect(scenario.viewModel.countdown == 3)
        #expect(!scenario.viewModel.isPlaying)
        scenario.viewModel.togglePlay()
        #expect(scenario.viewModel.countdown == nil)
        #expect(!scenario.viewModel.isPlaying)
    }

    @Test func studioPlaysAtOnceWithNoCountdownOrAwayFromTheTop() {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.togglePlay()
        #expect(scenario.viewModel.isPlaying && scenario.viewModel.countdown == nil, "countdown Off")
        scenario.viewModel.pause()
        scenario.viewModel.session.camera.countdown = .three
        scenario.viewModel.updateLayout(contentHeight: 3000)
        scenario.viewModel.jump(lines: 20)
        scenario.viewModel.togglePlay()
        #expect(scenario.viewModel.isPlaying && scenario.viewModel.countdown == nil, "resuming is not starting")
    }

    @Test func theFirstTakeGoesStraightToItsReviewAndTheSecondStartsOnPickYourBest() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.stopAnyway()
        #expect(scenario.takes.takes.count == 1)
        #expect(!scenario.viewModel.reviewStartsWithPick)
        await scenario.viewModel.retake()
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.stopAnyway()
        #expect(scenario.takes.takes.count == 2)
        #expect(scenario.viewModel.reviewStartsWithPick)
    }

    // MARK: - A take that ends on its own

    @Test func whenTheStorageFillsTheTakeIsSavedAndTheToastSaysWhy() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        let clip = RecordedClip(url: URL.temporaryDirectory.appending(path: "full-\(UUID().uuidString).mov"), duration: 12)
        scenario.camera.onRecordingEnded?(clip, .storageFull)
        #expect(!scenario.viewModel.isRecording)
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.toast.message == "Storage full · Take saved")
    }

    @Test func aCallInterruptsTheTakeAndItIsSaved() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        let clip = RecordedClip(url: URL.temporaryDirectory.appending(path: "call-\(UUID().uuidString).mov"), duration: 5)
        scenario.camera.onRecordingEnded?(clip, .interrupted)
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.toast.message == "Interrupted · Take saved")
    }

    @Test func anEndWithNothingToSaveSaysSo() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await scenario.viewModel.recordButtonTapped()
        scenario.camera.onRecordingEnded?(nil, .other)
        #expect(!scenario.viewModel.isRecording && scenario.takes.takes.isEmpty)
        #expect(scenario.toast.message == "The take couldn't be saved")
    }

    @Test func theReasonsComeFromTheSystemsErrors() {
        #expect(RecordingEndReason(error: NSError(domain: AVFoundationErrorDomain, code: AVError.diskFull.rawValue)) == .storageFull)
        #expect(RecordingEndReason(error: NSError(domain: AVFoundationErrorDomain, code: AVError.sessionWasInterrupted.rawValue)) == .interrupted)
        #expect(RecordingEndReason(error: nil) == .other)
    }
}
