//
//  IdeaFocus.swift
//  Cue Studio
//

import Foundation

/// The idea the creator types says what the video is about; My Cue Voice says how they sound. A voice that lists topics tells a small model what to write
/// about, and it listens: a creator with "Daily Routine (Bureaucracy)" among their topics who asked for "my daily routine with AI is not going so well" got
/// "Bureaucracy in 5 Minutes" (measured on an iPhone 15 Pro, 7 October 2026). So the topics go to the model only when the idea is about them, and their
/// subtopics only when the idea names one: for anything else the video is about the idea and nothing else of the voice changes.
nonisolated enum IdeaFocus {
    /// An idea with fewer words than this is too little to tell what it is about: every topic stays (a format with no idea of its own, an empty field).
    private static let fewestWords = 2

    /// `topics` narrowed to the ones `idea` is about, each with only the subtopics the idea names. All of them when there is no idea to compare with.
    static func topics(_ topics: [VoiceTopicEntry], for idea: String?, language: String?) -> [VoiceTopicEntry] {
        guard let idea, !topics.isEmpty else { return topics }
        let ideaWords = words(in: idea, language: language)
        guard ideaWords.count >= fewestWords else { return topics }
        return topics.compactMap { entry in
            let names = [entry.topic.promptName, entry.topic.label]
            guard names.contains(where: { share(words(in: $0, language: nil), with: ideaWords) }) else { return nil }
            var narrowed = entry
            narrowed.subtopics = entry.subtopics.filter { share(words(in: $0, language: nil), with: ideaWords) }
            return narrowed
        }
    }

    // MARK: - Matching

    /// The meaningful words of `text`, folded to lowercase without accents, without the words that say nothing about a subject.
    static func words(in text: String, language: String?) -> [String] {
        let filler = WritingLexicon.lexicon(for: language)?.filler ?? []
        return text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 && !commonWords.contains($0) && !filler.contains($0) }
    }

    /// Whether one of `topic`'s words is one of `idea`'s: the same word, or the same start of a longer one ("learn" for "learning", "routine" for "routines").
    private static func share(_ topic: [String], with idea: [String]) -> Bool {
        topic.contains { word in idea.contains { same(word, $0) } }
    }

    private static func same(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard lhs.count >= 5, rhs.count >= 5 else { return false }
        return lhs.prefix(5) == rhs.prefix(5)
    }

    /// Words of every idea that are no subject, in the languages the app is written in (and the ones of a topic's own name: "and", "&").
    private static let commonWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "about", "from", "not", "but", "how", "why", "what", "when", "who", "are", "was", "has", "have", "my",
        "your", "our", "its", "his", "her", "their", "into", "out", "all", "any", "going", "well", "good", "new", "way", "ways", "tips", "tip", "day",
        "um", "uma", "de", "da", "do", "em", "no", "na", "com", "por", "para", "que", "os", "as", "los", "las", "una", "del", "con", "por", "sobre",
        "le", "la", "les", "des", "du", "une", "pour", "avec", "dans", "sur", "der", "die", "das", "und", "mit", "fur", "von", "il", "lo", "gli", "per",
    ]
}
