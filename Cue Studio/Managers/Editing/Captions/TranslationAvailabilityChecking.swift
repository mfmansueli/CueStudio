//
//  TranslationAvailabilityChecking.swift
//  Cue Studio
//

import Foundation

/// Whether this iPhone can translate between two languages, asked each time (never assumed from
/// the languages Cue's interface speaks).
protocol TranslationAvailabilityChecking: Sendable {
    func support(from source: Locale.Language, to target: Locale.Language) async -> TranslationSupport
}
