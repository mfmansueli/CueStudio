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
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var continuation: AsyncStream<String>.Continuation?

    func start(script: String) async -> SpeechTranscription? {
        startCount += 1
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

    func say(_ transcript: String) {
        continuation?.yield(transcript)
    }
}
