//
//  CleanUpHearing.swift
//  Cue Studio
//

import Foundation

/// What Clean up learned about the take's words besides its suggestions, so the Words tab says the truth when it opens again:
/// whether they were heard, and in which language (filler words are known only in some). How sure it could be of the pauses is
/// `PauseHearing` (`TakeEdit.pauseHearings`).
nonisolated struct CleanUpHearing: Codable, Hashable, Sendable {
    /// The language code the words were heard in ("en", "pt"); nil when no word could be heard (no speech model for the
    /// language on this iPhone, or recognition failed).
    var wordsLanguage: String?

    init(wordsLanguage: String? = nil) {
        self.wordsLanguage = wordsLanguage
    }

    /// The words were heard.
    var heardWords: Bool { wordsLanguage != nil }
}
