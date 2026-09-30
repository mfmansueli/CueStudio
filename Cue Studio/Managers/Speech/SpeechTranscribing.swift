//
//  SpeechTranscribing.swift
//  Cue Studio
//

import Foundation

/// On-device speech recognition for Voice follow. Tests drive it with a fake.
protocol SpeechTranscribing: AnyObject {
    /// Starts recognizing speech in the requested language; `script` gives recognition hints
    /// (names, numbers). Never listens in another language than the one requested.
    /// `preparation` hears what the start is waiting for (the model loading, or downloading).
    func start(
        script: String, language: SpeechLanguageRequest, preparation: @escaping (SpeechPreparation) -> Void
    ) async -> SpeechStartResult
    func stop()
}

extension SpeechTranscribing {
    func start(script: String, language: SpeechLanguageRequest) async -> SpeechStartResult {
        await start(script: script, language: language, preparation: { _ in })
    }
}
