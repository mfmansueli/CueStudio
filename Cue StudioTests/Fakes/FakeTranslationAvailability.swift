//
//  FakeTranslationAvailability.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Translation support decided by the test.
nonisolated final class FakeTranslationAvailability: TranslationAvailabilityChecking, @unchecked Sendable {
    var support: TranslationSupport = .installed

    func support(from source: Locale.Language, to target: Locale.Language) async -> TranslationSupport {
        support
    }
}
