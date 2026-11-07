//
//  CleanUpHearing.swift
//  Cue Studio
//

import Foundation

/// What Clean up learned about a recording besides its suggestions, so its tabs say the truth when they open again: whether
/// its words were heard (and in which language: filler words are known only in some), and whether its sound let pauses be told
/// from speech at all. Pauses come from the loudness alone, so they work whatever this says.
nonisolated struct CleanUpHearing: Codable, Hashable, Sendable {
    /// The language code the words were heard in ("en", "pt"); nil when no word could be heard (no speech model for the
    /// language on this iPhone, or recognition failed).
    var wordsLanguage: String?
    /// The background was too loud to tell the pauses from the speech (set by the noise estimate, D16): nothing listed is
    /// trusted to be a pause, and the creator is told so instead of "Your take flows".
    var isInconclusive = false

    init(wordsLanguage: String? = nil, isInconclusive: Bool = false) {
        self.wordsLanguage = wordsLanguage
        self.isInconclusive = isInconclusive
    }

    /// The words were heard.
    var heardWords: Bool { wordsLanguage != nil }
}
