//
//  SpeechTranscribing.swift
//  Cue Studio
//

import Foundation

/// On-device speech recognition for Voice follow. Tests drive it with a fake.
protocol SpeechTranscribing: AnyObject {
    /// Starts recognizing speech in the requested language (see `SpeechLanguageRequest`). Nil when
    /// that can't happen here (no model for the language, unsupported device) or `stop()` came
    /// first. Never falls back to another language.
    func start(script: String, language: SpeechLanguageRequest) async -> SpeechTranscription?
    func stop()
    /// Whether this device can listen in `language`, as the speech framework reports it.
    func availability(of language: CueLanguage) async -> SpeechLanguageAvailability
}
