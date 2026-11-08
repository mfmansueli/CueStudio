//
//  MyWordsSpelling.swift
//  Cue Studio
//

import Foundation

/// The capitals of My words on the words heard, after the script lent its spelling (`ScriptSpelling`): "iphone" becomes "iPhone"
/// and "tiktok," "TikTok,". Only a whole heard word that is the saved word but for its capitals (or full/half width) is written as
/// saved; a word that merely sounds or looks like it ("tick tock", "iphones") is never touched, and phrases of several words are
/// only recognition hints (`RecognitionHints`). The word keeps its times and the punctuation around it.
///
/// **Common words are never turned into a brand.** Only a saved word with a capital inside it, after a small letter ("iPhone",
/// "TikTok", "CapCut", "YouTube", "ChatGPT", "McKinsey"), is written this way: in lower case it is no everyday word, so ordinary
/// speech can't become the brand. A word capitalized only at its start ("Cue", "Notion", "Apple") or all in capitals ("US", "IT")
/// has an everyday twin ("take your cue", "an apple", "tell us"), so it stays a hint only: the recognizer, told about it, still
/// decides from the sentence how to write it.
nonisolated enum MyWordsSpelling {
    /// `heard` with My words' capitals where a whole word is one of them; the same words, in the same times.
    static func apply(to heard: [CaptionWord], myWords: [String]) -> [CaptionWord] {
        var spelling: [String: String] = [:]
        for word in myWords where rewrites(word) {
            spelling[MyWordsList.key(word)] = spelling[MyWordsList.key(word)] ?? word
        }
        guard !spelling.isEmpty else { return heard }
        return heard.map { word in
            let parts = split(word.text)
            guard !parts.core.isEmpty, let saved = spelling[MyWordsList.key(parts.core)], saved != parts.core else { return word }
            var written = word
            written.text = parts.before + saved + parts.after
            return written
        }
    }

    /// Whether `word`'s capitals may be written on what was heard: one word, with a capital right after a small letter.
    static func rewrites(_ word: String) -> Bool {
        guard !word.contains(where: \.isWhitespace) else { return false }
        return zip(word, word.dropFirst()).contains { $0.isLowercase && $1.isUppercase }
    }

    /// A heard word's punctuation before, the word itself, and its punctuation after ("“tiktok,”" → "“", "tiktok", ",”").
    private static func split(_ text: String) -> (before: String, core: String, after: String) {
        let marks = CharacterSet.punctuationCharacters.union(.whitespaces)
        let isMark = { (character: Character) in character.unicodeScalars.allSatisfy(marks.contains) }
        let before = text.prefix(while: isMark)
        let rest = text.dropFirst(before.count)
        let after = String(rest.reversed().prefix(while: isMark).reversed())
        let core = rest.dropLast(after.count)
        return (String(before), String(core), after)
    }
}
