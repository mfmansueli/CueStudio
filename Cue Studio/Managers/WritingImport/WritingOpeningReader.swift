//
//  WritingOpeningReader.swift
//  Cue Studio
//

import Foundation

/// How a text opens and how it ends, as the catalog of My Cue Voice names them (`VoiceChoiceCatalog`): read from the first sentence and the last
/// two, with the words of the language when Cue knows them. What isn't clear stays unnamed rather than guessed.
nonisolated enum WritingOpeningReader {
    /// The opening style of a text, by the English id of the catalog, or nil when it is none of those it can tell.
    static func opening(of text: String, language: String?) -> String? {
        guard let first = WritingText.sentences(in: text, language: language).first else { return nil }
        let lexicon = WritingLexicon.lexicon(for: language)
        let lowered = first.lowercased().replacingOccurrences(of: "’", with: "'")
        if lowered.hasPrefix("pov") { return "POV" }
        if WritingText.isQuestion(first) { return "Question" }
        let words = WritingText.words(in: first, language: language).prefix(8)
        let startsWithNumber = words.first.map { $0.key.contains(where: \.isNumber) || (lexicon?.numberWords.contains($0.key) ?? false) } ?? false
        if startsWithNumber || words.contains(where: { $0.key.contains(where: \.isNumber) }) { return "Start with a number" }
        guard let lexicon else { return nil }
        if lexicon.mistakeStarts.contains(where: lowered.hasPrefix) { return "Mistake to avoid" }
        if lexicon.storyStarts.contains(where: lowered.hasPrefix) { return "Story opener" }
        return nil
    }

    /// The endings of a text (the catalog's English ids): what it asks of the viewer in its last two sentences.
    static func endings(of text: String, language: String?) -> [String] {
        guard let lexicon = WritingLexicon.lexicon(for: language) else { return [] }
        let tail = WritingText.sentences(in: text, language: language).suffix(2).joined(separator: " ")
            .lowercased().replacingOccurrences(of: "’", with: "'")
        guard !tail.isEmpty else { return [] }
        var found: [String] = []
        func mentions(_ terms: [String]) -> Bool { terms.contains { tail.contains($0) } }
        if mentions(lexicon.linkInBio) { found.append("Link in bio") }
        if mentions(lexicon.tryIt) { found.append("Try it and tell me") }
        if mentions(lexicon.comment), !found.contains("Try it and tell me") { found.append("Comment your answer") }
        if mentions(lexicon.save) { found.append("Save this") }
        if mentions(lexicon.follow) { found.append("Follow for more") }
        return found
    }
}
