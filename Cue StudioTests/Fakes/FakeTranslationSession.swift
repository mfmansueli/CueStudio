//
//  FakeTranslationSession.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Translates by putting a tag in front, or fails.
final class FakeTranslationSession: CaptionTranslationSession {
    var fails = false
    /// Fails with this error instead (for the way the system says a pair can't be translated).
    var error: Error?
    private(set) var asked: [String] = []

    func translate(_ texts: [String]) async throws -> [String] {
        asked = texts
        if let error { throw error }
        if fails { throw URLError(.cannotConnectToHost) }
        return texts.map { "EN " + $0 }
    }
}
