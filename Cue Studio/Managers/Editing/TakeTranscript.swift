//
//  TakeTranscript.swift
//  Cue Studio
//

import Foundation

/// What was said in a take, word by word with timings, and in which language ("en", "pt"…).
nonisolated struct TakeTranscript: Hashable, Sendable {
    var words: [TimedWord]
    var languageCode: String
    /// Languages the script uses for a stretch of its own ("en" in a Portuguese script) that this take
    /// couldn't be heard in (no model for it here, or listening failed), so those stretches may be
    /// missing from the words. Empty when every language the script uses was heard.
    var unheardLanguages: [String] = []
}
