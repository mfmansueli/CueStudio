//
//  VoiceFollowingLatencyTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Speech
import Testing
@testable import Cue_Studio

/// How quickly Voice Following reacts, measured on this device's own speech recognition: a
/// recording of the script (`Fixtures/Speech`) plays in real time through the camera's audio path
/// into the real prompter, and the text is watched as it moves.
///
/// Reported, per language: how long listening takes to start (first time, after turning Voice
/// Following off and on, after switching Selfie ⇄ Studio), how long after speech begins the
/// indicator lights and the text first moves, how long after each word ends the text reaches the
/// next one (p50 / p95), how far the text ever gets ahead of what was said, and whether a quiet
/// or noisy room makes it think someone is talking. Nothing leaves the device.
///
/// Opt-in and on a device, like `VoiceFollowingSpeechTests`:
/// `TEST_RUNNER_CUE_SPEECH_E2E=1 xcodebuild … -only-testing:"Cue StudioTests/VoiceFollowingLatencyTests" test`.
@MainActor
@Suite(
    "Voice Following latency on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil)
)
struct VoiceFollowingLatencyTests {
    private struct Scenario {
        let viewModel: PrompterViewModel
        let camera: PlaybackCamera
        let preferences: PreferencesService
        let defaults: TestDefaults
        let words: ScriptWords
        let paragraphFrames: [Range<Double>]
    }

    /// One moment of the prompter, as the creator would see it.
    private struct Sample {
        let time: TimeInterval
        let isSpeaking: Bool
        let offset: Double
    }

    /// Words per laid-out line: the Selfie text window at the default size holds about five.
    private static let wordsPerLine = 5

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: - Tests

    /// How the text moves between recognized words.
    enum Tuning: String, CaseIterable, Sendable {
        /// The shipping settings: running a little ahead while the voice goes on, quick small steps.
        case current
        /// Waiting for every recognized word, one glide for everything: Voice Following before the
        /// lead and the adaptive glide, on the same build.
        case wordsOnly

        @MainActor
        func apply(to viewModel: PrompterViewModel) {
            guard self == .wordsOnly else { return }
            viewModel.maximumSpeechLead = 0
            viewModel.voiceGlide = VoiceGlide(small: PrompterScrollEngine.glideTime, large: PrompterScrollEngine.glideTime)
        }
    }

    /// English and Portuguese are also run with the earlier settings, to compare them.
    @Test(arguments: [CueLanguage.english, .portugueseBrazil], Tuning.allCases)
    func followsARecordingInRealTime(in language: CueLanguage, tuning: Tuning) async throws {
        try await follow(language, tuning: tuning)
    }

    /// Every other language Cue offers, with the shipping settings: how far the text gets, whether it
    /// ever runs ahead of the voice, how soon it follows each word. A language this device can't run is
    /// *not validated* (reported as skipped with the reason), never counted as passed.
    @Test(arguments: CueLanguage.allCases.filter { $0 != .english && $0 != .portugueseBrazil })
    func followsARecordingInEveryOtherLanguage(in language: CueLanguage) async throws {
        try await follow(language, tuning: .current)
    }

    private func follow(_ language: CueLanguage, tuning: Tuning) async throws {
        KeepScreenAwake.enable()
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let fixture: SpeechFixture
        do {
            fixture = try await makeFixture(language, script: script)
        } catch let reason as SpeechUnavailableReason {
            print("VOICE LATENCY \(language.rawValue): NOT VALIDATED · \(reason.message)")
            try Test.cancel("\(language.rawValue) not validated: \(reason.message)")
        }
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        tuning.apply(to: viewModel)

        let coldStart = uptime
        await viewModel.appear()
        guard try await waitUntil(timeout: 90, { viewModel.followsSpeech }) else {
            let reason = viewModel.speechUnavailable?.message ?? "no reason given"
            print("VOICE LATENCY \(language.rawValue): NOT VALIDATED · Voice Following didn't start: \(reason)")
            await viewModel.disappear()
            try Test.cancel("\(language.rawValue) not validated: Voice Following didn't start (\(reason))")
        }
        let startup = uptime - coldStart

        viewModel.play()
        let run = try await watch(scenario, playing: fixture)
        let metrics = Self.metrics(of: run.samples, start: run.start, fixture: fixture, scenario: scenario)
        let appMetrics = viewModel.voiceMetrics.summary

        let switchStart = uptime
        await viewModel.switchMode(to: .studio)
        _ = try await waitUntil(timeout: 30) { viewModel.followsSpeech }
        let toStudio = uptime - switchStart
        let backStart = uptime
        await viewModel.switchMode(to: .selfie)
        _ = try await waitUntil(timeout: 30) { viewModel.followsSpeech }
        let toSelfie = uptime - backStart

        let restartStart = uptime
        viewModel.setScrollMode(.steady)
        viewModel.scrollModeChanged()
        viewModel.setScrollMode(.voice)
        viewModel.scrollModeChanged()
        let restarted = try await waitUntil(timeout: 30) { viewModel.followsSpeech }
        let restart = uptime - restartStart
        let restartProblem = viewModel.speechUnavailable?.message ?? "none"
        await viewModel.disappear()
        #expect(restarted, "\(language.rawValue) didn't listen again after Voice Following was turned off and on: \(restartProblem)")

        let callbacks = run.callbacks.sorted()
        print(
            "VOICE LATENCY \(language.rawValue) selfie \(tuning.rawValue) · startup \(ms(startup)) · restart \(ms(restart))"
                + " · Selfie→Studio \(ms(toStudio)) · Studio→Selfie \(ms(toSelfie)) · \(metrics.summary)"
                + " · audio callback p50 \(percentile(callbacks, 0.5).map(us) ?? "–") p95 \(percentile(callbacks, 0.95).map(us) ?? "–")"
                + " max \(callbacks.last.map(us) ?? "–")"
        )
        print("VOICE METRICS \(language.rawValue) \(tuning.rawValue) · \(appMetrics)")
        #expect(metrics.reached >= 0.8, "\(language.rawValue) reached \(metrics.reached) of the words")
    }

    /// Voice Following turned off and on again and again (or the prompter opened and closed) in one
    /// run of the app: every new recognition still hears the words.
    @Test func everyNewRecognitionStillListens() async throws {
        let script = try #require(VoiceFollowingSpeechTests.scripts[.english])
        let fixture = try await makeFixture(.english, script: script, lead: 0.2)
        var results: [String] = []
        for round in 1...12 {
            let speech = SpeechRecognitionManager()
            guard case .listening(let transcription, _) = await speech.start(script: script, language: .language(.english)) else {
                results.append("\(round): didn't start")
                continue
            }
            let heard = Heard()
            let listener = Task { @MainActor in
                for await text in transcription.transcripts { heard.text = text }
            }
            // Two seconds of the recording, fed four times faster than real time.
            for item in fixture.buffers.prefix(Int(2 / fixture.bufferDuration)) {
                transcription.audio(item.buffer)
                try await Task.sleep(for: .milliseconds(5))
            }
            _ = try await waitUntil(timeout: 5) { heard.text.contains { $0.isLetter } }
            results.append("\(round): \(heard.text.contains { $0.isLetter } ? "heard" : "nothing")")
            listener.cancel()
            speech.stop()
        }
        print("VOICE SESSIONS \(results.joined(separator: " · "))")
        #expect(results.allSatisfy { $0.hasSuffix("heard") })
    }

    private final class Heard {
        var text = ""
    }

    /// The format recognition asks for, and whether knowing the microphone's own format would
    /// change it (`bestAvailableAudioFormat(compatibleWith:considering:)`).
    @Test(arguments: [CueLanguage.english, .portugueseBrazil])
    func analyzerFormats(for language: CueLanguage) async throws {
        let resolver = SpeechLocaleResolver()
        guard case .success(let route) = await resolver.resolve(.language(language)) else {
            Issue.record("\(language.rawValue) can't be recognized here")
            return
        }
        let module: any SpeechModule = switch route.engine {
        case .transcriber:
            SpeechTranscriber(locale: route.locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        case .dictation:
            DictationTranscriber(locale: route.locale, contentHints: [], transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        }
        let plain = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
        func describe(_ format: AVAudioFormat?) -> String {
            guard let format else { return "none" }
            return "\(Int(format.sampleRate)) Hz \(format.channelCount) ch \(format.commonFormat.rawValue)"
        }
        var line = "VOICE FORMAT \(language.rawValue) \(route.engine) · best \(describe(plain))"
        for (name, common) in [("camera Int16", AVAudioCommonFormat.pcmFormatInt16), ("engine Float32", .pcmFormatFloat32)] {
            let natural = AVAudioFormat(commonFormat: common, sampleRate: 48_000, channels: 1, interleaved: common == .pcmFormatInt16)
            let considered = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: natural)
            line += " · considering 48 kHz \(name): \(describe(considered))"
        }
        print(line)
    }

    /// A room with steady noise: before anyone speaks, nothing should light up or move.
    @Test(arguments: [(CueLanguage.english, Float(-45)), (.english, -36), (.portugueseBrazil, -36)])
    func staysStillInANoisyRoom(language: CueLanguage, noise: Float) async throws {
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let fixture = try await makeFixture(language, script: script, lead: 3, noise: noise)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await viewModel.appear()
        guard try await waitUntil(timeout: 60, { viewModel.followsSpeech }) else {
            Issue.record("\(language.rawValue): Voice Following didn't start")
            return
        }
        viewModel.play()
        let run = try await watch(scenario, playing: fixture)
        await viewModel.disappear()
        let metrics = Self.metrics(of: run.samples, start: run.start, fixture: fixture, scenario: scenario)
        print("VOICE LATENCY \(language.rawValue) noise \(Int(noise)) dBFS · \(metrics.summary)")
        #expect(metrics.movedBeforeSpeech == false)
    }

    // MARK: - Running

    /// Word times of each recording, heard once: every transcription is one more recognizer, and
    /// the system allows only a few at a time.
    private static var timedWords: [CueLanguage: [TimedWord]] = [:]

    private func makeFixture(_ language: CueLanguage, script: String, lead: TimeInterval = 1.5, noise: Float? = nil) async throws -> SpeechFixture {
        final class BundleToken {}
        let words: [TimedWord]
        if let heard = Self.timedWords[language] {
            words = heard
        } else {
            let url = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-\(language.rawValue)", withExtension: "m4a"))
            words = try await CaptionTranscriber.transcript(in: url, language: .language(language), script: script).words
            Self.timedWords[language] = words
        }
        return try SpeechFixture.load(language, script: script, lead: lead, noise: noise, timedWords: words)
    }

    /// The prompter as the app builds it, with the real speech recognition and a camera that
    /// plays a recording. The script is on Auto-detect and Voice Following on "Same as Script".
    private func makeScenario(script text: String) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: text)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.camera.countdown = .off
        preferences.prompter.scrollMode = .voice
        let camera = PlaybackCamera()
        let viewModel = PrompterViewModel(
            launch: PrompterLaunch(scriptID: script.id, mode: .selfie),
            library: library, takes: TakeLibraryService(repository: FakeTakeRepository()), preferences: preferences,
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(),
            camera: camera, audio: FakeAudioMeter(), microphones: FakeMicrophones(), speech: SpeechRecognitionManager(),
            languages: TestData.languages(defaults: defaults.defaults),
            remote: RemoteControlService(transport: FakeRemoteTransport()), toast: ToastService()
        )
        // One paragraph laid out `wordsPerLine` words to a line.
        let words = ScriptWords(text: text)
        let lineHeight = viewModel.lineHeight
        let lines = (words.count + Self.wordsPerLine - 1) / Self.wordsPerLine
        let frames = [0..<(Double(lines) * lineHeight)]
        viewModel.updateLayout(contentHeight: Double(lines) * lineHeight)
        viewModel.updateParagraphFrame(frames[0], at: 0)
        return Scenario(
            viewModel: viewModel, camera: camera, preferences: preferences, defaults: defaults,
            words: words, paragraphFrames: frames
        )
    }

    /// Plays the fixture and samples the prompter every few milliseconds until a moment after it
    /// ends.
    private func watch(
        _ scenario: Scenario, playing fixture: SpeechFixture
    ) async throws -> (start: TimeInterval, samples: [Sample], callbacks: [TimeInterval]) {
        let (start, playback) = scenario.camera.play(fixture)
        var samples: [Sample] = []
        while uptime < start + fixture.duration + 0.5 || !playback.isFinished {
            samples.append(Sample(time: uptime, isSpeaking: scenario.viewModel.isVoiceActive, offset: scenario.viewModel.engine.offset))
            try await Task.sleep(for: .milliseconds(4))
        }
        return (start, samples, playback.callbackDurations)
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async throws -> Bool {
        let deadline = uptime + timeout
        while !condition() {
            guard uptime < deadline else { return false }
            try await Task.sleep(for: .milliseconds(2))
        }
        return true
    }

    // MARK: - Metrics

    private struct Metrics {
        var onsetToIndicator: TimeInterval?
        var onsetToMovement: TimeInterval?
        var lags: [TimeInterval] = []
        var reached = 0.0
        var maxOvershoot = 0
        var falseSpeaking = 0.0
        var movedBeforeSpeech = false

        var summary: String {
            let sorted = lags.sorted()
            return "onset→indicator \(onsetToIndicator.map(ms) ?? "never") · onset→first move \(onsetToMovement.map(ms) ?? "never")"
                + " · word→text p50 \(percentile(sorted, 0.5).map(ms) ?? "–") p95 \(percentile(sorted, 0.95).map(ms) ?? "–")"
                + " (n=\(lags.count)) · reached \(Int(reached * 100))% · max ahead \(maxOvershoot) words"
                + " · speaking before speech \(Int(falseSpeaking * 100))% · moved before speech \(movedBeforeSpeech)"
        }
    }

    private static func metrics(of samples: [Sample], start: TimeInterval, fixture: SpeechFixture, scenario: Scenario) -> Metrics {
        let words = scenario.words
        let lineHeight = scenario.viewModel.lineHeight
        let endOffset = scenario.viewModel.engine.endOffset
        let offsets = (0...words.count).map {
            words.offset(forWord: $0, paragraphFrames: scenario.paragraphFrames, lineHeight: lineHeight, endOffset: endOffset) ?? 0
        }
        let onset = start + fixture.speechOnset
        var metrics = Metrics()
        metrics.onsetToIndicator = samples.first { $0.time >= onset && $0.isSpeaking }.map { $0.time - onset }
        metrics.onsetToMovement = samples.first { $0.offset > 0.5 }.map { $0.time - onset }
        let quiet = samples.filter { $0.time < onset - 0.05 }
        metrics.falseSpeaking = quiet.isEmpty ? 0 : Double(quiet.count { $0.isSpeaking }) / Double(quiet.count)
        metrics.movedBeforeSpeech = quiet.contains { $0.offset > 0.5 }

        // When the text got at least halfway from a word to the next one, against when the word
        // before it was said. Words on the same spot of the guide can't be told apart.
        var distinct = 0
        for word in 1...words.count where offsets[word] > offsets[word - 1] + 0.5 {
            distinct += 1
            let halfway = (offsets[word - 1] + offsets[word]) / 2
            guard let reached = samples.first(where: { $0.offset >= halfway }) else { continue }
            metrics.lags.append(reached.time - (start + fixture.wordEnds[word - 1]))
        }
        metrics.reached = distinct > 0 ? Double(metrics.lags.count) / Double(distinct) : 0
        for sample in samples {
            let shown = offsets.firstIndex { $0 >= sample.offset - 0.5 } ?? words.count
            let said = fixture.wordEnds.count { start + $0 <= sample.time }
            metrics.maxOvershoot = max(metrics.maxOvershoot, shown - said)
        }
        return metrics
    }
}

private func ms(_ seconds: TimeInterval) -> String {
    "\(Int((seconds * 1000).rounded())) ms"
}

private func us(_ seconds: TimeInterval) -> String {
    "\(Int((seconds * 1_000_000).rounded())) µs"
}

private func percentile(_ sorted: [TimeInterval], _ fraction: Double) -> TimeInterval? {
    guard !sorted.isEmpty else { return nil }
    let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * fraction).rounded())))
    return sorted[index]
}
