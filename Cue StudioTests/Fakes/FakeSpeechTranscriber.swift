//
//  FakeSpeechTranscriber.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Recognition the test speaks through: `say(_:)` yields a transcript, as the real one does.
@MainActor
final class FakeSpeechTranscriber: SpeechTranscribing {
    /// False acts like a device or language without speech recognition.
    var isAvailable = true
    /// What `availability(of:)` answers; languages not listed are ready.
    var availability: [CueLanguage: SpeechLanguageAvailability] = [:]
    private(set) var startCount = 0
    private(set) var stopCount = 0
    /// The language each start asked for, oldest first.
    private(set) var requestedLanguages: [SpeechLanguageRequest] = []
    private var continuation: AsyncStream<String>.Continuation?

    func start(script: String, language: SpeechLanguageRequest) async -> SpeechTranscription? {
        startCount += 1
        requestedLanguages.append(language)
        if case .language(let requested) = language, availability[requested] == .unavailable { return nil }
        guard isAvailable else { return nil }
        let (transcripts, continuation) = AsyncStream.makeStream(of: String.self)
        self.continuation = continuation
        return SpeechTranscription(audio: { _ in }, transcripts: transcripts)
    }

    func stop() {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func availability(of language: CueLanguage) async -> SpeechLanguageAvailability {
        availability[language] ?? .ready
    }

    func say(_ transcript: String) {
        continuation?.yield(transcript)
    }
}
