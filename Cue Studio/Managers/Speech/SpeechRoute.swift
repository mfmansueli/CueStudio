//
//  SpeechRoute.swift
//  Cue Studio
//

import Foundation

/// How a request will be recognized on this device: which recognizer, in which locale.
nonisolated struct SpeechRoute: Equatable, Sendable {
    let engine: SpeechEngine
    let locale: Locale
    /// The Cue language asked for, or detected; nil for a detected language Cue doesn't list.
    let language: CueLanguage?
}
