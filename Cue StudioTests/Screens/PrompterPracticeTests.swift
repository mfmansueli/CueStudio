//
//  PrompterPracticeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first flight's practice (1.6): it reads the practice script with Voice Following when the microphone can be used, says what really
/// moves the text, never keeps the mode it chose for itself, and the line waits for the creator's voice after the count-in.
@MainActor
@Suite("Prompter practice")
struct PrompterPracticeTests {
    private final class TestClock {
        var now: TimeInterval = 100
    }

    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let speech: FakeSpeechTranscriber
        let preferences: PreferencesService
        let library: ScriptLibraryService
        let scriptID: UUID
        let clock: TestClock
        let defaults: TestDefaults
    }

    private static let follows = OnboardingScript.practice(followsVoice: true)
    private static let plain = OnboardingScript.practice(followsVoice: false)

    /// The practice on 1.4's script, as a creator who never chose a mode has it (Steady, the default).
    private func makeScenario(microphoneDenied: Bool = false, prepare: (FakeSpeechTranscriber) -> Void = { _ in }) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: Self.follows.text)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let preferences = PreferencesService(defaults: defaults.defaults)
        let camera = FakeCamera()
        let speech = FakeSpeechTranscriber()
        prepare(speech)
        let clock = TestClock()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script.id, mode: .selfie, isPractice: true),
            library: library, takes: TakeLibraryService(repository: FakeTakeRepository()), preferences: preferences,
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(),
            camera: camera, audio: FakeAudioMeter(), microphones: FakeMicrophones(), speech: speech,
            languages: TestData.languages(defaults: defaults.defaults), remote: RemoteControlService(transport: FakeRemoteTransport()),
            toast: ToastService(), microphone: MicrophoneAccess(isDenied: { microphoneDenied }), clock: { clock.now },
            speechRestartDelay: .milliseconds(20)
        )
        let lineHeight = viewModel.lineHeight
        viewModel.updateLayout(contentHeight: 6 * lineHeight)
        viewModel.updateParagraphFrame(0..<(2 * lineHeight), at: 0)
        viewModel.updateParagraphFrame((2 * lineHeight)..<(5 * lineHeight), at: 1)
        viewModel.updateParagraphFrame((5 * lineHeight)..<(6 * lineHeight), at: 2)
        return Scenario(
            viewModel: viewModel, camera: camera, speech: speech, preferences: preferences, library: library, scriptID: script.id,
            clock: clock, defaults: defaults
        )
    }

    private func text(_ scenario: Scenario) -> String? {
        scenario.library.script(id: scenario.scriptID)?.text
    }

    /// Display frames for `seconds`, a microphone buffer each frame.
    private func run(_ scenario: Scenario, for seconds: Double, level: Float = -70) async {
        for _ in 0..<Int((seconds * 60).rounded()) {
            scenario.clock.now += 1.0 / 60
            scenario.camera.hear(level: level, at: scenario.clock.now, duration: 1.0 / 60)
            for _ in 0..<5 { await Task.yield() }
            scenario.viewModel.advance(by: 1.0 / 60)
        }
    }

    // MARK: - The mode

    @Test func thePracticeFollowsTheVoiceWithoutChangingTheSavedMode() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.preferences.prompter.scrollMode == .steady)
        await scenario.viewModel.appear()
        #expect(scenario.viewModel.session.prompter.scrollMode == .voice)
        await Wait.until { scenario.viewModel.followsSpeech }
        #expect(scenario.viewModel.practiceVoice == .following)
        #expect(scenario.speech.startCount == 1, "recognition gets ready as the practice opens, before the tap")
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .steady)
    }

    /// "Record my first video" keeps Voice Following for that take, but the creator's saved mode only changes when they pick one.
    @Test func recordingForRealKeepsTheSavedModeUnlessTheCreatorPicksOne() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.leavePractice()
        #expect(scenario.viewModel.session.prompter.scrollMode == .voice)
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .steady)

        let picked = makeScenario()
        defer { picked.defaults.tearDown() }
        await picked.viewModel.appear()
        picked.viewModel.leavePractice()
        picked.viewModel.setScrollMode(.voice)
        await picked.viewModel.disappear()
        #expect(picked.preferences.prompter.scrollMode == .voice)
    }

    // MARK: - What the script says

    @Test func whileRecognitionGetsReadyTheScriptStillSaysItFollowsTheVoice() async {
        let scenario = makeScenario { $0.holdsStart = true }
        defer { scenario.defaults.tearDown() }
        let opening = Task { await scenario.viewModel.appear() }
        await Wait.until { scenario.speech.startCount == 1 }
        #expect(scenario.viewModel.practiceVoice == .preparing)
        #expect(text(scenario) == Self.follows.text)
        scenario.speech.finishPreparing()
        await opening.value
        await Wait.until { scenario.viewModel.followsSpeech }
        #expect(scenario.viewModel.practiceVoice == .following)
        await scenario.viewModel.disappear()
    }

    @Test func withoutTheMicrophoneItScrollsSteadilyAndTheScriptDropsTheClaim() async {
        let scenario = makeScenario(microphoneDenied: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.viewModel.session.prompter.scrollMode == .steady)
        #expect(scenario.viewModel.practiceVoice == .steady)
        #expect(text(scenario) == Self.plain.text)
        #expect(scenario.speech.startCount == 0, "nothing listens without the microphone")
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .steady)
    }

    @Test func whenTheWordsCantBeFollowedTheTextMovesWithTheVoiceAndTheScriptDropsTheClaim() async {
        let scenario = makeScenario { $0.unavailable = .unsupported(.thai) }
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await Wait.until { scenario.viewModel.practiceVoice == .scrollsWhileTalking }
        #expect(scenario.viewModel.practiceVoice == .scrollsWhileTalking)
        #expect(text(scenario) == Self.plain.text)
        await scenario.viewModel.disappear()
    }

    // MARK: - The count-in and the silence after it

    /// The count-in, READ! and the seconds of silence after it never move the line; the first word does.
    @Test(.timeLimit(.minutes(1))) func theLineWaitsThroughTheCountInAndTheSilenceForTheFirstWord() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await viewModel.appear()
        await Wait.until { viewModel.followsSpeech }
        await run(scenario, for: 0.6)
        viewModel.beginPracticeReading()
        // Something said during the count-in is not where the reading starts.
        scenario.speech.say("an idea is good")
        while viewModel.practiceStage != .reading {
            await run(scenario, for: 0.1)
        }
        #expect(viewModel.engine.offset == 0)
        await run(scenario, for: 6)
        #expect(viewModel.engine.offset == 0)
        scenario.speech.say("an idea is good seeing it become a video")
        for _ in 0..<5 { await Task.yield() }
        await run(scenario, for: 1, level: -20)
        #expect(viewModel.engine.offset > 0)
        await viewModel.disappear()
    }
}
