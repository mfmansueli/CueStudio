//
//  CaptionTranscript.swift
//  Cue Studio
//

import Foundation

/// What speech recognition heard in the take, word by word, kept apart from the captions: the
/// creator's corrections never overwrite it, so a line can always be compared with what was said.
nonisolated struct CaptionTranscript: Codable, Hashable, Sendable {
    var words: [CaptionWord]
    /// The language it was heard in ("pt", "ja"…).
    var languageCode: String

    /// The words heard between two moments of the recording, as said.
    func text(in span: TimeSpan) -> String {
        CaptionText.joined(words.filter { $0.end > span.start + 0.01 && $0.start < span.end - 0.01 }.map(\.text))
    }
}
