//
//  WritingText.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Reading a text the way a person does: sentences and words, in the language it is written in.
nonisolated enum WritingText {
    /// The sentences of `text`, trimmed.
    static func sentences(in text: String, language: String? = nil) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        if let language { tokenizer.setLanguage(NLLanguage(rawValue: VoiceFingerprint.base(language))) }
        var found: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { found.append(sentence) }
            return true
        }
        return found
    }

    /// A word as it was written and where.
    struct Word: Hashable, Sendable {
        /// Lowercased, apostrophes straightened.
        let key: String
        let range: Range<String.Index>
    }

    /// The words of `text` (letters and digits; punctuation is not a word).
    static func words(in text: String, language: String? = nil) -> [Word] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language { tokenizer.setLanguage(NLLanguage(rawValue: VoiceFingerprint.base(language))) }
        var found: [Word] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            var token = text[range].lowercased().replacingOccurrences(of: "’", with: "'")
            // "i'm" is one word to a speaker; the tokenizer keeps the contraction together except for some quotes.
            token = token.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            if token.contains(where: { $0.isLetter || $0.isNumber }) { found.append(Word(key: token, range: range)) }
            return true
        }
        return found
    }

    /// The language of `text` as a code ("en", "pt"), or nil when it can't be told.
    static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage, dominant != .undetermined else { return nil }
        let code = dominant.rawValue
        // Chinese keeps its script ("zh-Hans") in NaturalLanguage; the base is what the measures care about.
        return VoiceFingerprint.base(code)
    }

    /// Whether `sentence` ends as a question or an exclamation, in any script.
    static func isQuestion(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: CharacterSet(charactersIn: "\"”’)]} \n"))
        guard let last = trimmed.last else { return false }
        return "?？؟".contains(last) || (trimmed.first == "¿")
    }

    static func isExclamation(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: CharacterSet(charactersIn: "\"”’)]} \n"))
        guard let last = trimmed.last else { return false }
        return "!！".contains(last)
    }

    /// Emoji in `text`: symbols drawn in colour by default.
    static func emojiCount(in text: String) -> Int {
        text.unicodeScalars.filter { $0.properties.isEmojiPresentation || ((0x2600...0x27BF).contains($0.value) && $0.properties.isEmoji) }.count
    }
}
