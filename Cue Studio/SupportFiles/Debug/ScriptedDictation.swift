//
//  ScriptedDictation.swift
//  Cue Studio
//

#if DEBUG
import AVFAudio
import Foundation

/// Dictation for UI tests (`-uiTestDictation`): no microphone, no model. The simulator can't
/// recognize speech, so this "hears" a fixed text, a word at a time, the way the real recognizer
/// grows its transcript, and lets the tests tap through the whole flow.
@MainActor
final class ScriptedDictation: SpeechTranscribing, AudioLevelMetering {
    enum Scenario: String {
        /// Hears `words`, then keeps listening until stopped.
        case speech
        /// Says what the creator refused.
        case denied
        /// A language this iPhone can't recognize.
        case unavailable
        /// Starts listening and hears nothing.
        case silence
    }

    let scenario: Scenario
    private let words: [String]
    /// What it hears: nothing, in the silent scenario.
    private var heardWords: [String] { scenario == .silence ? [] : words }
    private var continuation: AsyncStream<String>.Continuation?
    private var feed: Task<Void, Never>?

    init(scenario: Scenario, text: String) {
        self.scenario = scenario
        words = text.split(separator: " ").map(String.init)
    }

    var microphone: MicrophoneAccess {
        let denied = scenario == .denied
        return MicrophoneAccess(isDenied: { denied }, request: { !denied })
    }

    // MARK: - SpeechTranscribing

    func start(script: String, language: SpeechLanguageRequest, preparation: @escaping (SpeechPreparation) -> Void) async -> SpeechStartResult {
        preparation(.preparing)
        if scenario == .unavailable { return .unavailable(.noRecognition) }
        let (transcripts, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        let words = heardWords
        feed = Task {
            var heard: [String] = []
            for word in words {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                heard.append(word)
                continuation.yield(heard.joined(separator: " "))
            }
        }
        let route = SpeechRoute(engine: .transcriber, locale: Locale(identifier: "en-US"), language: .english)
        return .listening(SpeechTranscription(audio: { _ in }, transcripts: transcripts), route)
    }

    func stop() {
        feed?.cancel()
        feed = nil
        continuation?.finish()
        continuation = nil
    }

    /// The last words arrive at once, then the transcript ends, like a real finalization.
    func finish() async {
        feed?.cancel()
        feed = nil
        if !heardWords.isEmpty { continuation?.yield(heardWords.joined(separator: " ")) }
        continuation?.finish()
        continuation = nil
    }

    // MARK: - AudioLevelMetering

    private var levelHandler: (@Sendable (AudioLevelSample) -> Void)?
    private var ticker: Task<Void, Never>?

    func startMetering() async -> Bool {
        ticker = Task { [weak self] in
            var time = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                time = ProcessInfo.processInfo.systemUptime
                self?.levelHandler?(AudioLevelSample(level: -30, time: time, duration: 0.1))
            }
        }
        return true
    }

    func stopMetering() {
        ticker?.cancel()
        ticker = nil
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {}

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {
        levelHandler = handler
    }
}
#endif
