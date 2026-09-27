//
//  SpeechTranscribing.swift
//  Cue Studio
//

import Foundation

/// On-device speech recognition for Voice follow. Tests drive it with a fake.
protocol SpeechTranscribing: AnyObject {
    /// Starts recognizing speech in the language `script` is written in. Nil when that can't
    /// happen here (no model for the language, unsupported device) or `stop()` came first.
    func start(script: String) async -> SpeechTranscription?
    func stop()
}
