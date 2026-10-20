//
//  FakeSpokenLanguageListener.swift
//  Cue StudioTests
//

import Foundation
import os
@testable import Cue_Studio

/// Rates each language from a table (nil: this iPhone can't judge it), saying which it was asked for and whether it could download.
final class FakeSpokenLanguageListener: SpokenLanguageListening, @unchecked Sendable {
    private let scores: [CueLanguage: SpokenLanguageScore]
    /// Languages that fail to listen (as when the system's few places for languages are taken).
    private let failing: Set<CueLanguage>
    private let state = OSAllocatedUnfairLock(initialState: [(CueLanguage, Bool)]())

    init(_ scores: [CueLanguage: SpokenLanguageScore], failing: Set<CueLanguage> = []) {
        self.scores = scores
        self.failing = failing
    }

    /// Each call: the language and whether its model could be downloaded.
    var calls: [(CueLanguage, Bool)] { state.withLock { $0 } }

    func score(of clip: URL, in language: CueLanguage, mayDownload: Bool) async throws -> SpokenLanguageScore? {
        state.withLock { $0.append((language, mayDownload)) }
        if failing.contains(language) { throw CocoaError(.featureUnsupported) }
        return scores[language]
    }
}
