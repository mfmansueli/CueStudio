//
//  SpeechTranscribing.swift
//  Cue Studio
//

import Foundation

/// On-device speech recognition for Voice follow. Tests drive it with a fake.
protocol SpeechTranscribing: AnyObject {
    /// Starts recognizing speech in the requested language; `script` gives recognition hints
    /// (names, numbers). Never listens in another language than the one requested.
    func start(script: String, language: SpeechLanguageRequest) async -> SpeechStartResult
    func stop()
}
