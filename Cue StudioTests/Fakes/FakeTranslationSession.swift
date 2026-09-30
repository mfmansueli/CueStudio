//
//  FakeTranslationSession.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Translates by putting a tag in front, or fails.
final class FakeTranslationSession: CaptionTranslationSession {
    var fails = false
    private(set) var asked: [String] = []

    func translate(_ texts: [String]) async throws -> [String] {
        asked = texts
        if fails { throw URLError(.cannotConnectToHost) }
        return texts.map { "EN " + $0 }
    }
}
