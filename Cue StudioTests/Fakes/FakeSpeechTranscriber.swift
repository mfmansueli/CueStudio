//
//  FakeSpeechTranscriber.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Recognition the test speaks through: `say(_:)` yields a transcript, as the real one does.
@MainActor
final class FakeSpeechTranscriber: SpeechTranscribing {
    /// Set, acts like a device or language without speech recognition, for this reason.
    var unavailable: SpeechUnavailableReason?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    /// The language each start asked for.
    private(set) var requests: [SpeechLanguageRequest] = []
    /// What a start reports waiting for before it answers, in order.
    var preparationSteps: [SpeechPreparation] = []
    /// Set, a start waits until `finishPreparing()`, the way a model loads or downloads.
    var holdsStart = false
    private var heldStart: CheckedContinuation<Void, Never>?
    private var continuation: AsyncStream<String>.Continuation?

    /// Kept for tests written before the reason existed.
    var isAvailable: Bool {
        get { unavailable == nil }
        set { unavailable = newValue ? nil : .noRecognition }
    }

    func start(
        script: String, language: SpeechLanguageRequest, preparation: @escaping (SpeechPreparation) -> Void
    ) async -> SpeechStartResult {
        startCount += 1
        requests.append(language)
        for step in preparationSteps { preparation(step) }
        if holdsStart {
            await withCheckedContinuation { heldStart = $0 }
        }
        if let unavailable { return .unavailable(unavailable) }
        let (transcripts, continuation) = AsyncStream.makeStream(of: String.self)
        self.continuation = continuation
        let listening: CueLanguage? = switch language {
        case .language(let language): language
        case .detect(let text, _): LanguageDetector.language(in: text)
        }
        let route = SpeechRoute(engine: .transcriber, locale: listening?.speechLocale ?? Locale(identifier: "en-US"), language: listening)
        return .listening(SpeechTranscription(audio: { _ in }, transcripts: transcripts), route)
    }

    func stop() {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func say(_ transcript: String) {
        continuation?.yield(transcript)
    }

    /// Lets a held start answer.
    func finishPreparing() {
        heldStart?.resume()
        heldStart = nil
    }
}
