//
//  SpokenLanguageListening.swift
//  Cue Studio
//

import Foundation

/// Hears a short stretch of a take in one language and says how well it understood it (`SpokenLanguageIdentifier`).
nonisolated protocol SpokenLanguageListening: Sendable {
    /// Nil when this iPhone can't judge the language: no recognizer that rates its words, or (unless `mayDownload`) its model isn't
    /// on the iPhone yet. Throws `CancellationError` when cancelled.
    func score(of clip: URL, in language: CueLanguage, mayDownload: Bool) async throws -> SpokenLanguageScore?
}
