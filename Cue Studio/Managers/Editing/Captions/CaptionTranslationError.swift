//
//  CaptionTranslationError.swift
//  Cue Studio
//

import Foundation

/// Why translating captions failed, in the two ways that ask for different things from the creator.
nonisolated enum CaptionTranslationError: Error, Equatable, Sendable {
    /// The system can't translate this pair of languages (or one of them): trying again won't help.
    case unsupportedPair
}
