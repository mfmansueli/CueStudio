//
//  AIPlanFailure.swift
//  Cue Studio
//

import Foundation

/// Why no model can take a request, told apart because each one asks for something different:
/// another language, waiting a little, or nothing the creator can do.
nonisolated enum AIPlanFailure: Error, Equatable, Sendable {
    /// This device can't run Apple Intelligence.
    case deviceNotSupported
    /// Apple Intelligence is off in Settings.
    case turnedOff
    /// The model is still downloading or getting ready.
    case modelPreparing
    /// A model is there, but not in this language (the first one the request needs that it doesn't write).
    case unsupportedLanguage(Locale.Language)
}
