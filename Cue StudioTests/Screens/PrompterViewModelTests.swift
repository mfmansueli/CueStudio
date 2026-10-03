//
//  PrompterViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("PrompterViewModel")
struct PrompterViewModelTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: FakeCamera
        let audio: FakeAudioMeter
        let speech: FakeSpeechTranscriber
        let takes: TakeLibraryService
        let preferences: PreferencesService
        let microphones: FakeMicrophones
        let remote: FakeRemoteTransport
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(
        script: Script? = TestData.script(), mode: PrompterMode = .selfie, monetization: Bool = true,
        voiceLanguage: VoiceFollowingLanguage = .sameAsScript
    ) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.monetizationGoals = monetization
        let camera = FakeCamera()
        let audio = FakeAudioMeter()
        let speech = FakeSpeechTranscriber()
        let microphones = FakeMicrophones()
        let remote = FakeRemoteTransport()
        let toast = ToastService()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script?.id, mode: mode),
            library: library, takes: takes, preferences: preferences, profile: profile, rules: TestData.rulesService(),
            camera: camera, audio: audio, microphones: microphones, speech: speech,
            remote: RemoteControlService(transport: remote), toast: toast, voiceFollowingLanguage: voiceLanguage
        )
        return Scenario(
            viewModel: viewModel, camera: camera, audio: audio, speech: speech, takes: takes,
            preferences: preferences, microphones: microphones, remote: remote, toast: toast, defaults: defaults
        )
    }

    /// Voice follow on a two-paragraph script, laid out as two lines, 50 pt of spacing, two lines.
    private func makeVoiceScenario(mode: PrompterMode = .studio) async -> Scenario {
        let scenario = makeScenario(script: TestData.script(text: "One two three four.\nFive six seven eight."), mode: mode)
        scenario.preferences.prompter.scrollMode = .voice
        let lineHeight = scenario.viewModel.lineHeight
        scenario.viewModel.updateLayout(contentHeight: 150 + 2 * lineHeight)
        scenario.viewModel.updateParagraphFrame(0..<(2 * lineHeight), at: 0)
        scenario.viewModel.updateParagraphFrame(150..<(150 + 2 * lineHeight), at: 1)
        scenario.viewModel.scrollModeChanged()
        await waitUntil { scenario.viewModel.followsSpeech }
        return scenario
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    /// Lets the tasks the view model started catch up (the transcript reaching the tracker).
    private func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }

    /// A few seconds of display frames.
    private func runFrames(_ viewModel: PrompterViewModel) {
        for _ in 0..<300 { viewModel.advance(by: 1.0 / 60) }
    }

    @Test func offersTheDestinationPresetWithoutApplyingIt() async {
        let scenario = makeScenario(script: TestData.script(platform: .youtube))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.viewModel.showsRecommendation)
        #expect(scenario.viewModel.session.recommendation?.platform == .youtube)
        #expect(scenario.camera.startedSettings.last?.aspect == .portrait)
        #expect(scenario.camera.startedSettings.last?.resolution == .hd1080)
        #expect(scenario.camera.startCount == 1)
        await scenario.viewModel.disappear()
    }

    @Test func acceptingTheDestinationPresetAppliesItToTheCamera() async {
        let scenario = makeScenario(script: TestData.script(platform: .youtube))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.useRecommendedSetup()
        await scenario.viewModel.cameraSettingsChanged()
        #expect(scenario.camera.appliedSettings.last?.aspect == .landscape)
        #expect(scenario.camera.appliedSettings.last?.resolution == .uhd4K)
        #expect(scenario.preferences.camera.aspect == .portrait)
        #expect(!scenario.viewModel.showsRecommendation)
        await scenario.viewModel.disappear()
    }

    @Test func opensWithTheFullTextWindow() async {
        let scenario = makeScenario(script: TestData.script(platform: .linkedin))
        defer { scenario.defaults.tearDown() }
        scenario.preferences.prompter.readingWidth = 0.5
        scenario.preferences.prompter.textWindowHeight = 200
        await scenario.viewModel.appear()
        #expect(scenario.preferences.prompter.readingWidth == 0.93)
        #expect(scenario.preferences.prompter.textWindowHeight == 380)
        #expect(scenario.viewModel.session.camera.aspect == .portrait)
        #expect(scenario.viewModel.session.conflicts.map(\.field) == [.format])
        await scenario.viewModel.disappear()
    }

    @Test func createForFromTheCameraMovesTheScriptAndOffersItsSetup() async {
        let script = TestData.script(platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.platformChipTapped()
        #expect(scenario.viewModel.sheet == .destination)
        scenario.viewModel.setPlatform(.stories)
        #expect(scenario.viewModel.sheet == nil)
        #expect(scenario.viewModel.script?.platform == .stories)
        #expect(scenario.viewModel.session.recommendation?.platform == .stories)
        #expect(scenario.toast.message == "Create for Instagram Stories")
    }

    @Test func freestyleChipCyclesTheFrame() {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        scenario.preferences.camera.aspect = .portrait
        scenario.viewModel.platformChipTapped()
        #expect(scenario.viewModel.sheet == nil)
        #expect(scenario.viewModel.session.camera.aspect == .vertical)
        #expect(scenario.preferences.camera.aspect == .portrait)
    }

    @Test func scrollModeSwitchesFromTheToolbar() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setScrollMode(.voice)
        #expect(scenario.preferences.prompter.scrollMode == .voice)
    }

    @Test func recordStartsRightAwayWithoutCountdown() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.isRecording)
        #expect(scenario.camera.recordingsStarted == 1)
        #expect(scenario.viewModel.isPlaying)
        await scenario.viewModel.disappear()
    }

    @Test func countdownRunsBeforeRecordingAndCanBeCancelled() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.preferences.camera.countdown = .three
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.countdown == 3)
        #expect(!scenario.viewModel.isRecording)
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.countdown == nil)
        #expect(scenario.camera.recordingsStarted == 0)
    }

    @Test func microphonePillOpensAudioInputBeforeRecording() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.canChangeAudioInput)
        scenario.viewModel.openAudioInput()
        #expect(scenario.viewModel.sheet == .audioInput)
        scenario.viewModel.sheet = nil

        await scenario.viewModel.recordButtonTapped()
        #expect(!scenario.viewModel.canChangeAudioInput)
        scenario.viewModel.openAudioInput()
        #expect(scenario.viewModel.sheet == nil)
        await scenario.viewModel.disappear()
    }

    @Test func audioInputStaysPutDuringTheCountdown() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.preferences.camera.countdown = .three
        await scenario.viewModel.recordButtonTapped()
        #expect(!scenario.viewModel.canChangeAudioInput)
        scenario.viewModel.openAudioInput()
        #expect(scenario.viewModel.sheet == nil)
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.canChangeAudioInput)
    }

    @Test func stoppingShortOfTheMinimumWarnsFirst() async {
        let scenario = makeScenario(script: TestData.script(platform: .tiktok))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.showsStopWarning)
        #expect(scenario.viewModel.isRecording)
        #expect(scenario.viewModel.stopWarningTitle == "1:00 short of 1:00")

        await scenario.viewModel.stopAnyway()
        #expect(!scenario.viewModel.isRecording)
        #expect(scenario.takes.takes.count == 1)
        #expect(scenario.viewModel.reviewingTake?.duration == 42)
    }

    @Test func keepGoingDismissesTheWarning() async {
        let scenario = makeScenario(script: TestData.script(platform: .tiktok))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        scenario.viewModel.keepRecording()
        #expect(!scenario.viewModel.showsStopWarning)
        #expect(scenario.viewModel.isRecording)
        await scenario.viewModel.disappear()
    }

    @Test func platformsWithoutMinimumStopImmediately() async {
        let scenario = makeScenario(script: TestData.script(platform: .reels))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        #expect(!scenario.viewModel.isRecording)
        #expect(scenario.viewModel.reviewingTake != nil)
    }

    @Test func freestyleRecordsWithoutAScript() async {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        #expect(!scenario.viewModel.isPlaying)
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.reviewingTake?.isFreestyle == true)
    }

    @Test func cameraNotReadyDoesNotRecord() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.camera.status = .unauthorized
        await scenario.viewModel.recordButtonTapped()
        #expect(!scenario.viewModel.isRecording)
        #expect(scenario.toast.message == "The camera isn't ready")
    }

    @Test func retakeReturnsToTheCamera() async {
        let scenario = makeScenario(script: TestData.script(platform: .reels))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.retake()
        #expect(scenario.viewModel.reviewingTake == nil)
        #expect(scenario.viewModel.mode == .selfie)
        #expect(scenario.viewModel.engine.offset == 0)
    }

    @Test func advanceScrollsAndStopsAtTheEnd() {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(100)), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.updateLayout(contentHeight: 1000)
        scenario.viewModel.play()
        scenario.viewModel.advance(by: 1)
        // The default 0.7×, 10 points per word.
        #expect(abs(scenario.viewModel.engine.offset - ReadTime.wordsPerMinute(speed: 0.7) / 60 * 10) < 0.0001)
        scenario.viewModel.advance(by: 1000)
        #expect(scenario.viewModel.engine.isAtEnd)
        #expect(!scenario.viewModel.isPlaying)
    }

    @Test func voiceFollowWaitsForSpeech() {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(100)), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.preferences.prompter.scrollMode = .voice
        scenario.viewModel.updateLayout(contentHeight: 1000)
        scenario.viewModel.play()
        scenario.viewModel.advance(by: 1)
        #expect(scenario.viewModel.engine.offset == 0)
        scenario.viewModel.pause()
    }

    @Test func voiceFollowWaitsForTheFirstWords() async {
        let scenario = await makeVoiceScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.followsSpeech)
        scenario.viewModel.play()
        runFrames(scenario.viewModel)
        #expect(scenario.viewModel.engine.offset == 0)
        await scenario.viewModel.disappear()
    }

    @Test func voiceFollowScrollsToTheWordBeingRead() async {
        let scenario = await makeVoiceScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.play()
        scenario.speech.say("one two three four")
        await settle()
        runFrames(scenario.viewModel)
        // The next word to read opens the second paragraph.
        #expect(scenario.viewModel.engine.offset == 150)
        await scenario.viewModel.disappear()
    }

    @Test func voiceFollowIgnoresTalkOffScript() async {
        let scenario = await makeVoiceScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.play()
        scenario.speech.say("hold on let me fix the light")
        await settle()
        runFrames(scenario.viewModel)
        #expect(scenario.viewModel.engine.offset == 0)
        await scenario.viewModel.disappear()
    }

    @Test func readingTheLastWordEndsTheScript() async {
        let scenario = await makeVoiceScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.play()
        scenario.speech.say("one two three four five six seven eight")
        await settle()
        runFrames(scenario.viewModel)
        #expect(scenario.viewModel.engine.isAtEnd)
        #expect(!scenario.viewModel.isPlaying)
        await scenario.viewModel.disappear()
    }

    @Test func studioModeListensThroughTheMeter() async {
        let scenario = await makeVoiceScenario(mode: .studio)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.audio.audioHandler != nil)
        #expect(scenario.camera.audioHandler == nil)
        await scenario.viewModel.disappear()
    }

    @Test func selfieModeListensThroughTheCamera() async {
        let scenario = await makeVoiceScenario(mode: .selfie)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.camera.audioHandler != nil)
        await scenario.viewModel.disappear()
    }

    @Test func steadyScrollingStopsListening() async {
        let scenario = await makeVoiceScenario()
        defer { scenario.defaults.tearDown() }
        scenario.preferences.prompter.scrollMode = .steady
        scenario.viewModel.scrollModeChanged()
        #expect(!scenario.viewModel.followsSpeech)
        #expect(scenario.audio.audioHandler == nil)
        #expect(scenario.speech.stopCount > 0)
    }

    @Test func withoutSpeechRecognitionVoiceFollowUsesTheLevel() async {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(100)), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.speech.isAvailable = false
        scenario.preferences.prompter.scrollMode = .voice
        scenario.viewModel.scrollModeChanged()
        await waitUntil { scenario.speech.startCount > 0 }
        await settle()
        #expect(!scenario.viewModel.followsSpeech)
        await scenario.viewModel.disappear()
    }

    // MARK: - Voice Following language

    /// Voice follow on `script` with the given Voice Following language, until recognition was asked.
    private func startListening(to script: Script, voiceLanguage: VoiceFollowingLanguage) async -> Scenario {
        let scenario = makeScenario(script: script, mode: .studio, voiceLanguage: voiceLanguage)
        scenario.preferences.prompter.scrollMode = .voice
        scenario.viewModel.scrollModeChanged()
        await waitUntil { scenario.speech.startCount > 0 }
        await settle()
        return scenario
    }

    @Test func scriptsWithoutALanguageAreDetectedAsBefore() async {
        let scenario = await startListening(to: TestData.script(), voiceLanguage: .sameAsScript)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.speech.requestedLanguages == [.detectFromScript])
        #expect(scenario.viewModel.followsSpeech)
        await scenario.viewModel.disappear()
    }

    @Test func voiceFollowingListensInTheScriptsLanguage() async {
        let script = TestData.script(text: "Bom dia, pessoal.", language: .portugueseBrazil)
        let scenario = await startListening(to: script, voiceLanguage: .sameAsScript)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.speech.requestedLanguages == [.language(.portugueseBrazil)])
        await scenario.viewModel.disappear()
    }

    @Test func voiceFollowingLanguageWinsOverTheScripts() async {
        let script = TestData.script(text: "Bom dia, pessoal.", language: .portugueseBrazil)
        let scenario = await startListening(to: script, voiceLanguage: .language(.english))
        defer { scenario.defaults.tearDown() }
        #expect(scenario.speech.requestedLanguages == [.language(.english)])
        #expect(scenario.viewModel.followsSpeech)
        await scenario.viewModel.disappear()
    }

    @Test func anUnavailableLanguageSaysSoAndNeverSwitches() async {
        let scenario = makeScenario(script: TestData.script(language: .thai), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.speech.availability[.thai] = .unavailable
        scenario.preferences.prompter.scrollMode = .voice
        scenario.viewModel.scrollModeChanged()
        await waitUntil { scenario.toast.message != nil }
        #expect(scenario.speech.requestedLanguages == [.language(.thai)])
        #expect(!scenario.viewModel.followsSpeech)
        #expect(scenario.toast.message == "Voice Following can't listen in Thai on this device. The text moves while you speak.")
        await scenario.viewModel.disappear()
    }

    @Test func arabicScriptsReadRightToLeft() {
        let arabic = makeScenario(script: TestData.script(text: "مرحبا بكم في القناة"))
        defer { arabic.defaults.tearDown() }
        #expect(arabic.viewModel.isScriptRightToLeft)
        let english = makeScenario(script: TestData.script(text: "Hello everyone"))
        defer { english.defaults.tearDown() }
        #expect(!english.viewModel.isScriptRightToLeft)
    }

    @Test func speedStartsAtTheNaturalPace() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.preferences.prompter.speed == 0.7)
    }

    @Test func speedMovesInTenthsWithinRange() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setSpeed(1.04)
        #expect(scenario.viewModel.session.prompter.speed == 1)
        scenario.viewModel.setSpeed(5)
        #expect(scenario.viewModel.session.prompter.speed == 2)
        scenario.viewModel.setSpeed(0.1)
        #expect(scenario.viewModel.session.prompter.speed == 0.3)
        #expect(scenario.preferences.prompter.speed == 0.7)
    }

    @Test func attachingAScriptToFreestyle() {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.hasScript)
        // The attached script only needs to exist in the library the view model reads.
        scenario.viewModel.attach(TestData.script())
        #expect(scenario.toast.message == "Script added")
    }

    @Test func cameraShortcutsChangeThisTakeAndSaveTheRest() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.cycleAspect()
        scenario.viewModel.flipCamera()
        scenario.viewModel.cycleCountdown()
        #expect(scenario.viewModel.session.camera.aspect == .vertical)
        #expect(scenario.viewModel.session.camera.lens == .wide)
        // Frame and lens are Creator Setup: they change for this take only.
        #expect(scenario.preferences.camera.aspect == .portrait)
        #expect(scenario.preferences.camera.lens == .front)
        // The countdown isn't part of it and is saved as before.
        #expect(scenario.preferences.camera.countdown == .three)
    }
}
