//
//  VoiceFingerprint.swift
//  Cue Studio
//

import Foundation

/// What was measured of the creator's writing when they imported it: numbers, never words. A small model imitates a style it is shown only
/// roughly, so the measured habits are also told to it as plain rules (`VoiceFingerprintRules`) and checked on the script it writes.
nonisolated struct VoiceFingerprint: Codable, Hashable, Sendable {
    /// The language the writing is in ("en", "pt"); the measures only mean something for scripts in that language.
    var language: String
    /// How many separate texts and words it was measured on.
    var pieces: Int
    var words: Int
    var wordsPerSentence: Double
    /// Shares (0...1) of the sentences that end with a question mark or an exclamation mark.
    var questionShare: Double
    var exclamationShare: Double
    var emojiPer100Words: Double
    /// Letters per word.
    var averageWordLength: Double
    /// Words they use for "I" and for "we" (the speaker, not the audience).
    var singularWords: Int
    var pluralWords: Int
    /// The middle text's length in words.
    var medianWords: Int
    var measuredAt: Date

    /// Fewer words than this and the measures are an impression, not a habit.
    static let reliableWords = 150

    var isReliable: Bool { words >= Self.reliableWords && pieces >= 2 }

    /// Whether the numbers describe scripts written in `code` ("en", "pt-BR" counts as "pt"); a request in another language ignores them.
    func applies(toLanguage code: String?) -> Bool {
        guard let code else { return true }
        return Self.base(code) == Self.base(language)
    }

    /// "pt-BR" and "pt_BR" are "pt".
    static func base(_ code: String) -> String {
        String(code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? Substring(code)).lowercased()
    }
}
