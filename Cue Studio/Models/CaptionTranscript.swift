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
    /// The recording it was heard in: nil for the take itself, else a montage's other recording.
    var sourceID: UUID?
    /// How it was heard (`currentVersion` when made now; nil in one saved before versions): a take
    /// heard by an older way is heard again when captions are made, so it gets what the newer one hears.
    var version: Int? = CaptionTranscript.currentVersion
    /// Languages the script uses that the take couldn't be heard in, so stretches in them may be
    /// missing (nil when every one was heard, and in a transcript saved before this was kept).
    var unheardLanguages: [String]?

    /// 2: a script in more than one language is heard in each of them (`MixedLanguageMerge`).
    static let currentVersion = 2

    var isCurrent: Bool { (version ?? 1) >= Self.currentVersion }

    /// The words heard between two moments of the recording, as said.
    func text(in span: TimeSpan) -> String {
        CaptionText.joined(words.filter { $0.end > span.start + 0.01 && $0.start < span.end - 0.01 }.map(\.text))
    }
}
