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
    /// Stops listening but lets what was heard in the last words be finalized first; returns when
    /// the transcript has ended. Dictation uses it so no word is lost at the stop.
    func finish() async
}

extension SpeechTranscribing {
    func finish() async {
        stop()
    }

    func start(script: String, language: SpeechLanguageRequest) async -> SpeechStartResult {
        await start(script: script, language: language, preparation: { _ in })
    }
}
