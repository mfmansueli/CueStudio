//
//  PrompterScrollModeDefaultTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Voice Following is the prompter's default (the owner, 30/10/2026): a first session opens in it; one that can't follow the voice (no
/// microphone, a language this iPhone can't recognize) reads Steady for itself, says why and never saves it; a Steady the creator picks is
/// remembered.
@MainActor
@Suite("Prompter scroll mode default")
struct PrompterScrollModeDefaultTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let speech: FakeSpeechTranscriber
        let preferences: PreferencesService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(
        mode: PrompterMode = .selfie, microphoneDenied: Bool = false, saved: ScrollMode? = nil,
        prepare: (FakeSpeechTranscriber) -> Void = { _ in }
    ) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: "One two three four.\nFive six seven eight.")
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        if let saved { preferences.prompter.scrollMode = saved }
        let camera = FakeCamera()
        if mode == .studio { camera.status = .unavailable }
        let speech = FakeSpeechTranscriber()
        prepare(speech)
        let toast = ToastService()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script.id, mode: mode),
            library: library, takes: TakeLibraryService(repository: FakeTakeRepository()), preferences: preferences,
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(),
            camera: camera, audio: FakeAudioMeter(), microphones: FakeMicrophones(), speech: speech,
            languages: TestData.languages(defaults: defaults.defaults), remote: RemoteControlService(transport: FakeRemoteTransport()),
            toast: toast, microphone: MicrophoneAccess(isDenied: { microphoneDenied }), speechRestartDelay: .milliseconds(20)
        )
        return Scenario(viewModel: viewModel, speech: speech, preferences: preferences, toast: toast, defaults: defaults)
    }

    @Test func aFreshInstallReadsWithVoiceFollowing() async {
        #expect(PrompterSettings().scrollMode == .voice)
        for mode in [PrompterMode.selfie, .studio] {
            let scenario = makeScenario(mode: mode)
            defer { scenario.defaults.tearDown() }
            #expect(scenario.preferences.prompter.scrollMode == .voice)
            await scenario.viewModel.appear()
            #expect(scenario.viewModel.session.prompter.scrollMode == .voice)
            await Wait.until { scenario.viewModel.followsSpeech }
            #expect(scenario.speech.startCount == 1)
            await scenario.viewModel.disappear()
            #expect(scenario.preferences.prompter.scrollMode == .voice)
        }
    }

    /// Settings saved before Voice Following was the default, with no mode in them, open in it too.
    @Test func settingsSavedWithoutAModeOpenInVoiceFollowing() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"speed":0.7,"size":40}"#.utf8))
        #expect(settings.scrollMode == .voice)
    }

    @Test func withoutTheMicrophoneASessionReadsSteadyAndKeepsTheSavedMode() async {
        let scenario = makeScenario(microphoneDenied: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        #expect(scenario.viewModel.session.prompter.scrollMode == .steady)
        #expect(scenario.speech.startCount == 0, "nothing listens without the microphone")
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .voice)
    }

    /// A language this iPhone can't recognize: the toast says so ("Can't follow Thai · Scrolling"), the text scrolls Steady, and the
    /// next session tries Voice Following again.
    @Test func aLanguageItCantFollowReadsSteadyAndSaysSo() async {
        let scenario = makeScenario { $0.unavailable = .unsupported(.thai) }
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        await Wait.until { scenario.viewModel.session.prompter.scrollMode == .steady }
        #expect(scenario.viewModel.session.prompter.scrollMode == .steady)
        #expect(scenario.toast.message == SpeechUnavailableReason.unsupported(.thai).message)
        #expect(!scenario.viewModel.followsSpeech)
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .voice)
    }

    @Test func aSteadyTheCreatorPicksIsRemembered() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.setScrollMode(.steady)
        #expect(scenario.viewModel.session.prompter.scrollMode == .steady)
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .steady)

        let next = makeScenario(saved: .steady)
        defer { next.defaults.tearDown() }
        await next.viewModel.appear()
        #expect(next.viewModel.session.prompter.scrollMode == .steady)
        #expect(next.speech.startCount == 0)
        await next.viewModel.disappear()
    }

    /// A fallback the creator overrides by picking Steady is theirs: it is remembered like any pick.
    @Test func pickingAModeAfterAFallbackIsRemembered() async {
        let scenario = makeScenario(microphoneDenied: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.appear()
        scenario.viewModel.setScrollMode(.steady)
        await scenario.viewModel.disappear()
        #expect(scenario.preferences.prompter.scrollMode == .steady)
    }
}
