//
//  AppleTranslationAvailability.swift
//  Cue Studio
//

import Foundation
import Translation

/// `LanguageAvailability`, from Apple's Translation framework.
nonisolated struct AppleTranslationAvailability: TranslationAvailabilityChecking {
    func support(from source: Locale.Language, to target: Locale.Language) async -> TranslationSupport {
        switch await LanguageAvailability().status(from: source, to: target) {
        case .installed: .installed
        case .supported: .downloadable
        case .unsupported: .unsupported
        @unknown default: .unsupported
        }
    }
}
