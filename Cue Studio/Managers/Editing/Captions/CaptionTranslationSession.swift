//
//  CaptionTranslationSession.swift
//  Cue Studio
//

import Foundation

/// Translates sentences from one language to another, on the device.
protocol CaptionTranslationSession {
    /// `texts` translated, in the same order. Throws when the translation fails or is cancelled.
    func translate(_ texts: [String]) async throws -> [String]
}
