//
//  WritingLexicon.swift
//  Cue Studio
//

import Foundation

/// The words that tell a creator's habits apart in one language: who "I" and "we" are, what is only filler, what is slang, how a story, a
/// mistake or a call to action begins. Small on purpose: it only has to be right when it says something, and says nothing for a language it
/// doesn't know (the measures that need no words, like sentence length, still work in every language).
nonisolated struct WritingLexicon: Sendable {
    let singular: Set<String>
    let plural: Set<String>
    let filler: Set<String>
    let slang: Set<String>
    let mildSwearing: Set<String>
    /// Beginnings (lowercase) of a first sentence that starts a short story.
    let storyStarts: [String]
    /// Beginnings of a first sentence that warns of a mistake.
    let mistakeStarts: [String]
    /// Words (lowercase, whole words or phrases) of a last sentence that asks to save, follow, comment, try, or points to the bio.
    let save: [String]
    let follow: [String]
    let comment: [String]
    let linkInBio: [String]
    let tryIt: [String]
    /// Words for numbers a first sentence can start with ("three", "tres").
    let numberWords: Set<String>
    /// Average letters per word above which the words read as expert terms, and below which as plain, in this language.
    let expertWordLength: Double
    let plainWordLength: Double

    /// The lexicon of a language code ("en", "pt-BR"); nil for a language it doesn't cover.
    static func lexicon(for code: String?) -> WritingLexicon? {
        guard let code else { return nil }
        return all[VoiceFingerprint.base(code)]
    }

    /// Languages written without spaces between words: a "word" is whatever the tokenizer says, so lengths in words don't compare with other
    /// languages and no length is proposed for them.
    static let unspaced: Set<String> = ["ja", "zh", "th", "lo", "km", "my"]

    static func isUnspaced(_ code: String?) -> Bool {
        guard let code else { return false }
        return unspaced.contains(VoiceFingerprint.base(code))
    }
}
