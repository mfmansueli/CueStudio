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
        let languages: LanguageService
    }

    private func makeScenario(
        script: Script? = TestData.script(), mode: PrompterMode = .selfie,
        monetization: Bool = true, prompter: PrompterSettings = Self.steady, appLanguage: String? = nil
    ) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        preferences.prompter = prompter
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.monetizationGoals = monetization
        let camera = FakeCamera()
        // Studio with no camera (a Mac, no permission) listens through the meter, as before it recorded.
        if mode == .studio { camera.status = .unavailable }
        let audio = FakeAudioMeter()
        let speech = FakeSpeechTranscriber()
        let microphones = FakeMicrophones()
        let remote = FakeRemoteTransport()
        let toast = ToastService()
        let languages = TestData.languages(defaults: defaults.defaults, appLanguage: appLanguage)
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script?.id, mode: mode),
            library: library, takes: takes, preferences: preferences, profile: profile, rules: TestData.rulesService(),
            camera: camera, audio: audio, microphones: microphones, speech: speech, languages: languages,
            remote: RemoteControlService(transport: remote), toast: toast
        )
        return Scenario(
            viewModel: viewModel, camera: camera, audio: audio, speech: speech, takes: takes,
            preferences: preferences, microphones: microphones, remote: remote, toast: toast, defaults: defaults,
            languages: languages
        )
    }

    /// Saved settings with Steady, which most of these tests read at (Voice Following, the default, waits for a voice).
    private static var steady: PrompterSettings {
        var settings = PrompterSettings()
        settings.scrollMode = .steady
        return settings
    }

    /// Voice follow on a two-paragraph script, laid out as two lines, 50 pt of spacing, two lines.
    private func makeVoiceScenario(mode: PrompterMode = .studio) async -> Scenario {
        let scenario = makeScenario(script: TestData.script(text: "One two three four.\nFive six seven eight."), mode: mode)
        scenario.viewModel.session.prompter.scrollMode = .voice
        let lineHeight = scenario.viewModel.lineHeight
        scenario.viewModel.updateLayout(contentHeight: 150 + 2 * lineHeight)
        scenario.viewModel.updateParagraphFrame(0..<(2 * lineHeight), at: 0)
        scenario.viewModel.updateParagraphFrame(150..<(150 + 2 * lineHeight), at: 1)
        scenario.viewModel.scrollModeChanged()
        await Wait.until { scenario.viewModel.followsSpeech }
        return scenario
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

    @Test func opensWithTheCreatorsSavedTextWindow() async {
        var prompter = PrompterSettings()
        prompter.readingWidth = 0.5
        prompter.textWindowHeight = 200
        let scenario = makeScenario(script: TestData.script(platform: .linkedin), prompter: prompter)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.viewModel.session.prompter.readingWidth == 0.5)
        #expect(scenario.viewModel.session.prompter.textWindowHeight == 200)
        #expect(scenario.preferences.prompter == prompter)
        #expect(scenario.viewModel.session.camera.aspect == .portrait)
        #expect(scenario.viewModel.session.changes.map(\.item) == [.field(.format)])
        await scenario.viewModel.disappear()
    }

    /// The recorder's network chip changes this session's network only: the script keeps its own, the setup is offered for the new one
    /// and the next take is filed under it.
    @Test func createForFromTheCameraChangesTheSessionNeverTheScript() async {
        let script = TestData.script(platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.platformChipTapped()
        #expect(scenario.viewModel.sheet == .destination)
        scenario.viewModel.setPlatform(.stories)
        #expect(scenario.viewModel.sheet == nil)
        #expect(scenario.viewModel.platform == .stories)
        #expect(scenario.viewModel.script?.platform == .tiktok)
        #expect(scenario.viewModel.session.recommendation?.platform == .stories)
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.stopRecording(openReview: false)
        #expect(scenario.takes.takes.first?.platform == .stories)
        #expect(scenario.viewModel.script?.platform == .tiktok)
        await scenario.viewModel.disappear()
    }

    /// Freestyle starts at the creator's usual network and records under it; its chip opens the same picker, and the setup is offered
    /// only once the creator picks another network.
    @Test func freestyleStartsAtTheUsualNetworkAndItsChipPicksAnother() async {
        let scenario = makeScenario(script: nil)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.platform == CreatorProfile().defaultPlatform)
        #expect(scenario.viewModel.recommendation == nil)
        scenario.viewModel.platformChipTapped()
        #expect(scenario.viewModel.sheet == .destination)
        #expect(scenario.viewModel.session.camera.aspect == scenario.preferences.camera.aspect)
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.stopRecording(openReview: false)
        #expect(scenario.takes.takes.first?.platform == CreatorProfile().defaultPlatform)
        scenario.viewModel.setPlatform(.youtube)
        #expect(scenario.viewModel.session.recommendation?.platform == .youtube)
        await scenario.viewModel.disappear()
    }

    /// The switch changes this session at once; the pick is saved when the session ends (`rememberReadingLayout`).
    @Test func scrollModeSwitchesFromTheToolbar() {
        let scenario = makeScenario(prompter: PrompterSettings())
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setScrollMode(.steady)
        #expect(scenario.viewModel.session.prompter.scrollMode == .steady)
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

    /// A9: leaving Cue (Home, a call, Siri) during the countdown stops it, and coming back doesn't start the take.
    @Test func leavingCueDuringTheCountdownStopsIt() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.preferences.camera.countdown = .three
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.viewModel.countdown == 3)
        scenario.viewModel.sceneChanged(isActive: false)
        #expect(scenario.viewModel.countdown == nil)
        scenario.viewModel.sceneChanged(isActive: true)
        try? await Task.sleep(for: .milliseconds(1200))
        #expect(scenario.camera.recordingsStarted == 0)
        #expect(!scenario.viewModel.isRecording)
    }

    /// A9: a call or Split View taking the camera stops the countdown, and Record says why instead of starting a take that can't record.
    @Test func aCameraTakenByACallStopsTheCountdownAndSaysWhy() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.preferences.camera.countdown = .three
        await scenario.viewModel.recordButtonTapped()
        scenario.camera.interruption = .inUseElsewhere
        scenario.viewModel.cameraInterruptionChanged()
        #expect(scenario.viewModel.countdown == nil)
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.camera.recordingsStarted == 0)
        #expect(scenario.toast.message == CameraInterruption.inUseElsewhere.title)
        scenario.camera.interruption = nil
        scenario.preferences.camera.countdown = .off
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.camera.recordingsStarted == 1, "once the camera is back, Record records")
        await scenario.viewModel.disappear()
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

    @Test func aBackgroundChosenWhileRecordingGoesWithTheTake() async throws {
        let scenario = makeScenario(script: TestData.script(platform: .reels))
        defer { scenario.defaults.tearDown() }
        var blur = BackgroundEffect()
        blur.style = .blur
        scenario.camera.background = blur
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        let take = try #require(scenario.takes.takes.first)
        // A recipe: the recording keeps the camera's image, and it isn't marked Edited.
        #expect(take.edit?.background(for: nil)?.style == .blur)
        #expect(take.edit?.editedDuration == 42)
        #expect(!take.isEdited)
    }

    /// A10: the camera recorded less than was asked for (no 4K at 60 fps on this camera): the take says what it really is, so it isn't
    /// offered a 4K export that would only enlarge it, and the creator is told once per format.
    @Test func aTakeSaysTheFormatTheCameraReallyRecorded() async throws {
        let scenario = makeScenario(script: TestData.script(platform: .reels))
        defer { scenario.defaults.tearDown() }
        var asked = scenario.viewModel.session.camera
        asked.resolution = .uhd4K
        asked.frameRate = .fps60
        scenario.viewModel.session.camera = asked
        scenario.camera.deliveredResolution = .hd1080
        scenario.camera.deliveredFrameRate = .fps60
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        let take = try #require(scenario.takes.takes.first)
        #expect(take.resolution == .hd1080 && take.frameRate == .fps60)
        let told = String(localized: "Recorded in \("1080p") at \(60) fps · This camera can’t do \("4K") at \(60) fps")
        #expect(scenario.toast.message == told)
        scenario.toast.dismiss()
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        #expect(scenario.takes.takes.count == 2)
        #expect(scenario.toast.message != told, "said once per format")
    }

    @Test func withoutABackgroundTheTakeHasNoRecipe() async throws {
        let scenario = makeScenario(script: TestData.script(platform: .reels))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.recordButtonTapped()
        await scenario.viewModel.recordButtonTapped()
        #expect(try #require(scenario.takes.takes.first).edit == nil)
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
        // The default pace, 10 points per word.
        #expect(abs(scenario.viewModel.engine.offset - ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed) / 60 * 10) < 0.0001)
        scenario.viewModel.advance(by: 1000)
        #expect(scenario.viewModel.engine.isAtEnd)
        #expect(!scenario.viewModel.isPlaying)
    }

    @Test func voiceFollowWaitsForSpeech() {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(100)), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.session.prompter.scrollMode = .voice
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
        scenario.viewModel.session.prompter.scrollMode = .steady
        scenario.viewModel.scrollModeChanged()
        #expect(!scenario.viewModel.followsSpeech)
        #expect(scenario.audio.audioHandler == nil)
        #expect(scenario.speech.stopCount > 0)
    }

    @Test func withoutSpeechRecognitionVoiceFollowUsesTheLevel() async {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(100)), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.speech.isAvailable = false
        scenario.viewModel.session.prompter.scrollMode = .voice
        scenario.viewModel.scrollModeChanged()
        await Wait.until { scenario.speech.startCount > 0 }
        await settle()
        #expect(!scenario.viewModel.followsSpeech)
        await scenario.viewModel.disappear()
    }

    // MARK: - Voice Following language

    @Test func voiceFollowingListensInTheChosenLanguage() async {
        let scenario = makeScenario(
            script: TestData.script(text: "Esses são três hábitos que mudaram as minhas manhãs."), mode: .studio, appLanguage: "en"
        )
        defer { scenario.defaults.tearDown() }
        scenario.languages.voiceFollowingLanguage = .portugueseBrazil
        scenario.viewModel.session.prompter.scrollMode = .voice
        scenario.viewModel.scrollModeChanged()
        await Wait.until { scenario.viewModel.followsSpeech }
        #expect(scenario.speech.requests.last == .language(.portugueseBrazil))
        #expect(scenario.viewModel.listeningLanguage == .portugueseBrazil)
        await scenario.viewModel.disappear()
    }

    @Test func sameAsScriptListensInTheScriptsLanguage() async {
        let script = TestData.script(text: "Here are three habits.", language: .portugueseBrazil)
        let scenario = makeScenario(script: script, mode: .studio, appLanguage: "ja")
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.session.prompter.scrollMode = .voice
        scenario.viewModel.scrollModeChanged()
        await Wait.until { scenario.viewModel.followsSpeech }
        #expect(scenario.speech.requests.last == .language(.portugueseBrazil))
        await scenario.viewModel.disappear()
    }

    /// A language the device can't recognize is never swapped for another: the creator is told,
    /// once, and the text scrolls with the voice level.
    /// A language this iPhone can't recognize is never swapped for another: the toast says so, and the session reads Steady. Picking
    /// Voice again tries again, and says so again.
    @Test func anUnavailableLanguageIsExplainedNotReplaced() async {
        let scenario = makeScenario(script: TestData.script(text: TestData.words(100)), mode: .studio)
        defer { scenario.defaults.tearDown() }
        scenario.languages.voiceFollowingLanguage = .thai
        scenario.speech.unavailable = .unsupported(.thai)
        scenario.viewModel.setScrollMode(.voice)
        scenario.viewModel.scrollModeChanged()
        await Wait.until { scenario.viewModel.session.prompter.scrollMode == .steady }
        #expect(scenario.speech.requests == [.language(.thai)])
        #expect(!scenario.viewModel.followsSpeech)
        #expect(scenario.toast.message == SpeechUnavailableReason.unsupported(.thai).message)
        scenario.toast.dismiss()
        scenario.viewModel.setScrollMode(.voice)
        scenario.viewModel.scrollModeChanged()
        await Wait.until { scenario.viewModel.session.prompter.scrollMode == .steady }
        #expect(scenario.speech.requests == [.language(.thai), .language(.thai)])
        #expect(scenario.toast.message == SpeechUnavailableReason.unsupported(.thai).message)
        await scenario.viewModel.disappear()
    }

    @Test func anArabicScriptReadsRightToLeftInAnyInterface() {
        let arabic = makeScenario(script: TestData.script(text: "هذه ثلاث عادات غيرت صباحي.", language: .arabic))
        defer { arabic.defaults.tearDown() }
        #expect(arabic.viewModel.readsRightToLeft)
        let english = makeScenario(script: TestData.script(text: "Here are three habits."), appLanguage: "ar")
        defer { english.defaults.tearDown() }
        #expect(!english.viewModel.readsRightToLeft)
    }

    @Test func speedStartsAtTheNaturalPace() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.preferences.prompter.speed == ReadTime.naturalSpeed)
    }

    @Test func speedMovesInFiveWordsAMinuteWithinRange() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setSpeed(1.04)
        #expect(scenario.viewModel.session.prompter.speed == 225 / ReadTime.wordsPerMinuteAtOneX)
        // Past the ends, the range's ends: 0.2× and 2× of the natural pace (30 and 300 words a minute).
        scenario.viewModel.setSpeed(5)
        #expect(scenario.viewModel.session.prompter.speed == PrompterSettings.speedRange.upperBound)
        scenario.viewModel.setSpeed(0.1)
        #expect(scenario.viewModel.session.prompter.speed == PrompterSettings.speedRange.lowerBound)
        #expect(scenario.preferences.prompter.speed == ReadTime.naturalSpeed)
    }

    /// The remote's − and + move one stop of the slider (0.1×), and stop at its ends.
    @Test func theRemoteMovesTheSpeedOneStopATap() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.handle(.faster)
        #expect(scenario.viewModel.session.prompter.speed == SpeedScale.speed(forMultiple: 1.1))
        scenario.viewModel.handle(.slower)
        scenario.viewModel.handle(.slower)
        #expect(scenario.viewModel.session.prompter.speed == SpeedScale.speed(forMultiple: 0.9))
        for _ in 0..<30 { scenario.viewModel.handle(.faster) }
        #expect(scenario.viewModel.session.prompter.speed == PrompterSettings.speedRange.upperBound)
        #expect(scenario.viewModel.session.prompter.speedLabel == "2×")
        for _ in 0..<30 { scenario.viewModel.handle(.slower) }
        #expect(scenario.viewModel.session.prompter.speedLabel == SpeedScale.label(forMultiple: 0.2))
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
        scenario.viewModel.session.camera.aspect = .vertical
        scenario.viewModel.flipCamera()
        #expect(scenario.viewModel.session.camera.aspect == .vertical)
        #expect(scenario.viewModel.session.camera.lens == .wide)
        // Frame and lens are Creator Setup: they change for this take only.
        #expect(scenario.preferences.camera.aspect == .portrait)
        #expect(scenario.preferences.camera.lens == .front)
    }
}
