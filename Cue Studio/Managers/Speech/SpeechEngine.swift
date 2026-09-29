//
//  SpeechEngine.swift
//  Cue Studio
//

import Foundation

/// The two on-device recognizers of Apple's Speech framework (`SpeechAnalyzer` modules). Both run
/// entirely on the device, at no cost per use.
nonisolated enum SpeechEngine: CaseIterable, Sendable {
    /// `SpeechTranscriber`: Voice Following's original recognizer, tried first for every language.
    case transcriber
    /// `DictationTranscriber`: the system dictation model, for languages or devices the first one
    /// doesn't cover.
    case dictation
}
