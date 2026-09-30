//
//  AppleTranslationSession.swift
//  Cue Studio
//

import Foundation
import Translation

/// Apple's Translation framework, given by SwiftUI's `translationTask` (which handles downloading
/// the languages, asking first). Translation runs on the device: nothing is sent anywhere and
/// nothing is paid per use.
nonisolated final class AppleTranslationSession: CaptionTranslationSession, @unchecked Sendable {
    private let session: TranslationSession

    init(_ session: TranslationSession) {
        self.session = session
    }

    /// Sentence by sentence: each one is translated whole, with its own context.
    func translate(_ texts: [String]) async throws -> [String] {
        guard !texts.isEmpty else { return [] }
        try await session.prepareTranslation()
        var result: [String] = []
        for text in texts {
            try Task.checkCancellation()
            result.append(try await session.translate(text).targetText)
        }
        return result
    }
}
