//
//  FakeTranslationAvailability.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Translation support decided by the test.
nonisolated final class FakeTranslationAvailability: TranslationAvailabilityChecking, @unchecked Sendable {
    var support: TranslationSupport = .installed
    /// Runs while the iPhone is asked (the call is suspended): what the creator does meanwhile.
    var whileChecking: (@MainActor @Sendable () -> Void)?

    func support(from source: Locale.Language, to target: Locale.Language) async -> TranslationSupport {
        if let whileChecking { await whileChecking() }
        return support
    }
}
