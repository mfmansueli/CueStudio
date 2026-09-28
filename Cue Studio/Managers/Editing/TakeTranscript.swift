//
//  TakeTranscript.swift
//  Cue Studio
//

import Foundation

/// What was said in a take, word by word with timings, and in which language ("en", "pt"…).
nonisolated struct TakeTranscript: Hashable, Sendable {
    var words: [TimedWord]
    var languageCode: String
}
