//
//  ScriptedVoiceFollowing.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Voice Following's recognition for UI tests (`-uiTestVoiceFollowing`): the simulator can't recognize speech, so the prompter's states
/// are scripted. It listens and hears nothing (nobody speaks in a UI test), stays getting ready, or says this iPhone can't follow the words.
@MainActor
final class ScriptedVoiceFollowing: SpeechTranscribing {
    enum Scenario: String {
        /// Listens at once, in English, and hears nothing.
        case listening
        /// Loads its model and never finishes (until stopped).
        case preparing
        /// This iPhone can't follow the words.
        case unavailable
    }

    let scenario: Scenario
    private var continuation: AsyncStream<String>.Continuation?
    private var held: CheckedContinuation<Void, Never>?

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func start(script: String, language: SpeechLanguageRequest, preparation: @escaping (SpeechPreparation) -> Void) async -> SpeechStartResult {
        stop()
        preparation(.preparing)
        switch scenario {
        case .unavailable:
            return .unavailable(.noRecognition)
        case .preparing:
            await withCheckedContinuation { held = $0 }
            return .cancelled
        case .listening:
            let (transcripts, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
            self.continuation = continuation
            let route = SpeechRoute(engine: .transcriber, locale: Locale(identifier: "en-US"), language: .english)
            return .listening(SpeechTranscription(audio: { _ in }, transcripts: transcripts), route)
        }
    }

    func stop() {
        continuation?.finish()
        continuation = nil
        held?.resume()
        held = nil
    }
}
#endif
