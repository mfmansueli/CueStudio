//
//  PrompterViewModelVoiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Voice Following's timing in the prompter: the level of each buffer as it arrives, one
/// recognition kept across Selfie ⇄ Studio, the state while a model gets ready, and the text
/// running a little ahead of the words while the creator speaks.
@MainActor
@Suite("PrompterViewModel Voice Following")
struct PrompterViewModelVoiceTests {
    /// The prompter's clock, moved by the test.
    private final class TestClock {
        var now: TimeInterval = 100
    }

    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let audio: FakeAudioMeter
        let speech: FakeSpeechTranscriber
        let preferences: PreferencesService
        let languages: LanguageService
        let clock: TestClock
        let defaults: TestDefaults
    }

    /// A two-paragraph script laid out as two lines each, 50 pt apart, with Voice Following on.
    private func makeScenario(mode: PrompterMode = .studio, prepare: (FakeSpeechTranscriber) -> Void = { _ in }) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: "One two three four.\nFive six seven eight.")
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        preferences.prompter.scrollMode = .voice
        let camera = FakeCamera()
        // Studio with no camera (a Mac, no permission) listens through the meter, as before it recorded.
        if mode == .studio { camera.status = .unavailable }
        let audio = FakeAudioMeter()
        let speech = FakeSpeechTranscriber()
        prepare(speech)
        let languages = TestData.languages(defaults: defaults.defaults)
        let clock = TestClock()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script.id, mode: mode),
            library: library, takes: TakeLibraryService(repository: FakeTakeRepository()), preferences: preferences,
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(),
            camera: camera, audio: audio, microphones: FakeMicrophones(), speech: speech, languages: languages,
            remote: RemoteControlService(transport: FakeRemoteTransport()), toast: ToastService(), clock: { clock.now }
        )
        let lineHeight = viewModel.lineHeight
        viewModel.updateLayout(contentHeight: 150 + 2 * lineHeight)
        viewModel.updateParagraphFrame(0..<(2 * lineHeight), at: 0)
        viewModel.updateParagraphFrame(150..<(150 + 2 * lineHeight), at: 1)
        return Scenario(
            viewModel: viewModel, camera: camera, audio: audio, speech: speech, preferences: preferences,
            languages: languages, clock: clock, defaults: defaults
        )
    }

    private func startListening(_ scenario: Scenario) async {
        await scenario.viewModel.appear()
        await waitUntil { scenario.viewModel.followsSpeech }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    private func settle(_ yields: Int = 50) async {
        for _ in 0..<yields { await Task.yield() }
    }

    /// A microphone buffer at `level` dBFS arriving now, through this mode's microphone.
    private func hear(_ scenario: Scenario, _ level: Float, duration: TimeInterval = 1.0 / 60) async {
        switch scenario.viewModel.mode {
        case .selfie: scenario.camera.hear(level: level, at: scenario.clock.now, duration: duration)
        case .studio: scenario.audio.hear(level: level, at: scenario.clock.now, duration: duration)
        }
        await settle(5)
    }

    /// Display frames for `seconds`, with a microphone buffer each frame: at `level`, or a quiet
    /// room.
    private func run(_ scenario: Scenario, for seconds: Double, level: Float = -70) async {
        for _ in 0..<Int((seconds * 60).rounded()) {
            scenario.clock.now += 1.0 / 60
            await hear(scenario, level)
            scenario.viewModel.advance(by: 1.0 / 60)
        }
    }

    /// The room heard for a moment, as it is by the time anyone reads.
    private func learnTheRoom(_ scenario: Scenario) async {
        await run(scenario, for: 0.6)
    }

    // MARK: - Level as it arrives

    @Test(arguments: [PrompterMode.selfie, .studio])
    func theIndicatorLightsAsTheVoiceArrives(mode: PrompterMode) async {
        let scenario = makeScenario(mode: mode)
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        await learnTheRoom(scenario)
        #expect(!scenario.viewModel.isVoiceActive)
        await hear(scenario, -20, duration: 0.05)
        #expect(scenario.viewModel.isVoiceActive)
        #expect(scenario.viewModel.voiceLevel > 0.5)
        #expect(scenario.viewModel.voiceMetrics.onsetToIndicator.count == 1)
        await scenario.viewModel.disappear()
        #expect(scenario.camera.levelHandler == nil)
        #expect(scenario.audio.levelHandler == nil)
    }

    /// A fan louder than the usual threshold: once the room is learned, it's not a voice.
    @Test func steadyRoomNoiseStopsCountingAsSpeech() async {
        let scenario = makeScenario(mode: .selfie)
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        scenario.viewModel.play()
        await run(scenario, for: 4, level: -36)
        #expect(!scenario.viewModel.isVoiceActive)
        #expect(scenario.viewModel.engine.offset == 0)
        await run(scenario, for: 0.1, level: -15)
        #expect(scenario.viewModel.isVoiceActive)
        await scenario.viewModel.disappear()
    }

    // MARK: - One recognition per script

    @Test func switchingSelfieAndStudioKeepsListening() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        #expect(scenario.audio.audioHandler != nil)
        await scenario.viewModel.switchMode(to: .selfie)
        #expect(scenario.speech.startCount == 1)
        #expect(scenario.viewModel.followsSpeech)
        #expect(scenario.camera.audioHandler != nil)
        #expect(scenario.audio.audioHandler == nil)
        #expect(scenario.camera.levelHandler != nil)
        #expect(scenario.audio.levelHandler == nil)
        // Still following: the words land where they did before the switch.
        scenario.viewModel.play()
        scenario.speech.say("one two three four")
        await settle()
        await run(scenario, for: 5)
        #expect(scenario.viewModel.engine.offset == 150)
        await scenario.viewModel.disappear()
    }

    /// The second paragraph's frames for a layout that starts it at `top`, as the mode just entered reports them.
    private func layOut(_ viewModel: PrompterViewModel, secondParagraphAt top: Double) {
        let lineHeight = viewModel.lineHeight
        viewModel.updateLayout(contentHeight: top + 2 * lineHeight)
        viewModel.updateParagraphFrame(0..<(2 * lineHeight), at: 0)
        viewModel.updateParagraphFrame(top..<(top + 2 * lineHeight), at: 1)
        viewModel.updateLayout(contentHeight: top + 2 * lineHeight)
    }

    @Test func eachModeKeepsItsOwnPlace() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await startListening(scenario)
        // Studio: "Five" (the second paragraph) is on the guide.
        viewModel.drag(by: -150)
        #expect(viewModel.engine.offset == 150)
        // Selfie has not been visited: it starts at the top, whatever Studio did.
        await viewModel.switchMode(to: .selfie)
        layOut(viewModel, secondParagraphAt: 100)
        #expect(viewModel.engine.offset == 0)
        // Selfie reads on to its own second paragraph.
        viewModel.drag(by: -100)
        #expect(viewModel.engine.offset == 100)
        // Back in Studio, where it was left: 150 in Studio's layout, not Selfie's 100.
        await viewModel.switchMode(to: .studio)
        layOut(viewModel, secondParagraphAt: 150)
        #expect(viewModel.engine.offset == 150)
        // And Selfie is where Selfie was left.
        await viewModel.switchMode(to: .selfie)
        layOut(viewModel, secondParagraphAt: 100)
        #expect(viewModel.engine.offset == 100)
        await viewModel.disappear()
    }

    @Test func followingContinuesFromTheModesOwnPlace() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await startListening(scenario)
        viewModel.drag(by: -150)
        await viewModel.switchMode(to: .selfie)
        layOut(viewModel, secondParagraphAt: 100)
        // Selfie starts at the top: the words of the first line move it there, not to Studio's place.
        viewModel.play()
        scenario.speech.say("one two three four")
        await settle()
        await run(scenario, for: 5)
        #expect(viewModel.engine.offset == 100)
        await viewModel.disappear()
    }

    @Test func wordsReadInTheOtherModeDontPullTheTextThere() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await startListening(scenario)
        // Studio read through the second paragraph.
        viewModel.play()
        scenario.speech.say("one two three four five six seven eight")
        await settle()
        await run(scenario, for: 5)
        let before = scenario.speech.discardCount
        // Selfie starts at the top, with a fresh transcript: the recognizer is told to start over.
        await viewModel.switchMode(to: .selfie)
        layOut(viewModel, secondParagraphAt: 100)
        #expect(scenario.speech.discardCount == before + 1)
        #expect(viewModel.engine.offset == 0)
        await viewModel.disappear()
    }

    @Test func backToTheTopStartsTheTranscriptOver() async {
        let scenario = makeScenario(mode: .selfie)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await startListening(scenario)
        viewModel.play()
        scenario.speech.say("one two three four five six")
        await settle()
        await run(scenario, for: 5)
        #expect(viewModel.engine.offset > 0)
        // Rewinding while it plays: the words just heard must not match where they were read.
        let before = scenario.speech.discardCount
        viewModel.rewind()
        #expect(viewModel.engine.offset == 0)
        #expect(scenario.speech.discardCount == before + 1)
        viewModel.play()
        await run(scenario, for: 2)
        #expect(viewModel.engine.offset == 0)
        await viewModel.disappear()
    }

    @Test func aScrollAfterTheSwapIsNotPutBack() async {
        let scenario = makeScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await startListening(scenario)
        viewModel.drag(by: -150)
        await viewModel.switchMode(to: .selfie)
        viewModel.drag(by: -30)
        layOut(viewModel, secondParagraphAt: 100)
        #expect(viewModel.engine.offset != 0)
        await viewModel.disappear()
    }

    @Test func anotherLanguageStartsListeningAgain() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        scenario.languages.voiceFollowingLanguage = .portugueseBrazil
        scenario.viewModel.scrollModeChanged()
        await waitUntil { scenario.speech.startCount == 2 }
        #expect(scenario.speech.requests.last == .language(.portugueseBrazil))
        await scenario.viewModel.disappear()
    }

    // MARK: - Getting ready

    @Test func aDownloadIsShownUntilItListens() async {
        let scenario = makeScenario { speech in
            speech.holdsStart = true
            speech.preparationSteps = [.preparing, .downloading(.english, progress: 0.4)]
        }
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await waitUntil { scenario.speech.startCount == 1 }
        await settle()
        #expect(scenario.viewModel.voiceFollowStatus == .downloading(.english, progress: 0.4))
        #expect(!scenario.viewModel.followsSpeech)
        scenario.speech.finishPreparing()
        await waitUntil { scenario.viewModel.followsSpeech }
        #expect(scenario.viewModel.voiceFollowStatus == .followingWords)
        #expect(scenario.viewModel.voiceMetrics.downloaded)
        #expect(scenario.viewModel.voiceMetrics.startup != nil)
        await scenario.viewModel.disappear()
    }

    /// The model loads while the camera starts: recognition starts before anything else waits.
    @Test func recognitionStartsGettingReadyRightAway() async {
        let scenario = makeScenario(mode: .selfie) { $0.holdsStart = true }
        defer { scenario.defaults.tearDown() }
        let opening = Task { await scenario.viewModel.appear() }
        await waitUntil { scenario.speech.startCount == 1 }
        #expect(scenario.speech.startCount == 1)
        #expect(scenario.viewModel.voiceFollowStatus == .preparing)
        scenario.speech.finishPreparing()
        await opening.value
        await scenario.viewModel.disappear()
    }

    @Test func anUnavailableLanguageScrollsWhileTalkingAndSaysSo() async {
        let scenario = makeScenario { $0.unavailable = .unsupported(.thai) }
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await waitUntil { scenario.viewModel.speechUnavailable != nil }
        #expect(scenario.viewModel.voiceFollowStatus == .scrollsWhileTalking)
        await learnTheRoom(scenario)
        scenario.viewModel.play()
        await run(scenario, for: 0.5, level: -20)
        #expect(scenario.viewModel.engine.offset > 0)
        await scenario.viewModel.disappear()
    }

    // MARK: - Running ahead of the words

    /// Word by word, the text also moves while the voice goes on, a little past the last word
    /// recognized and never more than half a line.
    @Test func speakingRunsTheTextALittleAheadOfTheWords() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        let viewModel = scenario.viewModel
        viewModel.play()
        scenario.speech.say("one two")
        await settle()
        await run(scenario, for: 2)
        let confirmed = viewModel.engine.offset
        #expect(confirmed > 0)
        await run(scenario, for: 2, level: -20)
        #expect(viewModel.engine.offset > confirmed + 1)
        #expect(viewModel.engine.offset <= confirmed + viewModel.lineHeight * 0.5 + 0.5)
        await viewModel.disappear()
    }

    @Test func aPauseHoldsTheText() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        let viewModel = scenario.viewModel
        viewModel.play()
        scenario.speech.say("one two")
        await settle()
        await learnTheRoom(scenario)
        await run(scenario, for: 0.3, level: -20)
        await run(scenario, for: 2, level: -70)
        let held = viewModel.engine.offset
        await run(scenario, for: 2, level: -70)
        #expect(viewModel.engine.offset == held)
        await viewModel.disappear()
    }

    /// However long the creator talks, only the last word heard ends the script.
    @Test func theLeadNeverEndsTheScript() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        let viewModel = scenario.viewModel
        viewModel.play()
        scenario.speech.say("one two three four five six seven")
        await settle()
        await learnTheRoom(scenario)
        await run(scenario, for: 3, level: -20)
        #expect(!viewModel.engine.isAtEnd)
        #expect(viewModel.isPlaying)
        scenario.speech.say("one two three four five six seven eight")
        await settle()
        await run(scenario, for: 3, level: -20)
        #expect(viewModel.engine.isAtEnd)
        await viewModel.disappear()
    }

    @Test func noLeadWaitsForEveryWord() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await startListening(scenario)
        let viewModel = scenario.viewModel
        viewModel.maximumSpeechLead = 0
        viewModel.play()
        scenario.speech.say("one two")
        await settle()
        await run(scenario, for: 2)
        let confirmed = viewModel.engine.offset
        await run(scenario, for: 2, level: -20)
        #expect(viewModel.engine.offset == confirmed)
        await viewModel.disappear()
    }
}
