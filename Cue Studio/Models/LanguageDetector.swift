//
//  LanguageDetector.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// The language a text is written in, read from the text itself (Natural Language, on the device).
/// Scripts set to Auto-detect use it. It detects written text only: there is no reliable way to
/// tell the language someone is speaking before recognizing it, so Voice Following never guesses
/// that.
///
/// Creators mix languages: a few English words or a whole English phrase in a script written in
/// Portuguese. The language of a text is the one most of its words are in, sentence by sentence,
/// never the one its first words (or its most confident short phrase) happen to be in.
nonisolated enum LanguageDetector {
    /// Fewest words before the count by sentence is trusted over the whole text read at once.
    static let weighingMinimumWords = 8
    /// How sure the recognizer must be that a short phrase is in another language to call it one.
    static let foreignConfidence = 0.75

    /// ISO 639 code of the dominant language ("pt", "ja"), or nil when there's nothing to tell by.
    /// Cues aren't spoken, so they don't count. `preferring` (the creator's languages, such as the
    /// iPhone's) is a weak lean for text that could be either, never a vote against clear text.
    static func dominantLanguageCode(in text: String, preferring preferred: [String] = []) -> String? {
        let spoken = CueParser.stripCues(text)
        guard spoken.contains(where: { $0.isLetter }) else { return nil }
        let hints = hints(for: preferred)
        let whole = NLLanguageRecognizer()
        whole.languageHints = hints
        whole.processString(spoken)
        let wholeLanguage = whole.dominantLanguage.flatMap { $0 == .undetermined ? nil : $0 }
        let language = weighed(spoken, hints: hints, fallback: wholeLanguage) ?? wholeLanguage
        return language.flatMap { Locale.Language(identifier: $0.rawValue).languageCode?.identifier }
    }

    /// The detected language when Cue offers it.
    static func language(in text: String, preferring preferred: [String] = []) -> CueLanguage? {
        dominantLanguageCode(in: text, preferring: preferred).flatMap(CueLanguage.matching(languageCode:))
    }

    /// Whether `words`, a short stretch of a text written in `code`, are clearly in another
    /// language: an English phrase in a Portuguese script. Needs two words and some letters, since
    /// a lone word says nothing about its language.
    static func isForeign(_ words: [String], to code: String) -> Bool {
        let phrase = words.joined(separator: " ")
        guard words.count >= 2, phrase.filter(\.isLetter).count >= 8 else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(phrase)
        guard let top = recognizer.languageHypotheses(withMaximum: 1).first,
              top.key != .undetermined, top.value >= foreignConfidence,
              let found = Locale.Language(identifier: top.key.rawValue).languageCode?.identifier else { return false }
        return found != code
    }

    // MARK: - By sentence

    /// The language most of the words are in, each sentence counting for its words: nil when the
    /// text is too short for that to mean more than reading it whole.
    private static func weighed(_ text: String, hints: [NLLanguage: Double], fallback: NLLanguage?) -> NLLanguage? {
        var total = 0.0
        var weights: [NLLanguage: Double] = [:]
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            let count = Double(wordCount(of: sentence))
            guard count > 0 else { return true }
            let recognizer = NLLanguageRecognizer()
            recognizer.languageHints = hints
            recognizer.processString(sentence)
            total += count
            for (language, probability) in recognizer.languageHypotheses(withMaximum: 2) where language != .undetermined {
                weights[language, default: 0] += probability * count
            }
            return true
        }
        guard total >= Double(weighingMinimumWords) else { return nil }
        return weights.max { $0.value < $1.value }?.key ?? fallback
    }

    /// Words in a sentence; a script written without spaces counts two letters to a word.
    private static func wordCount(of sentence: String) -> Int {
        if WordSegmenter.containsUnspacedScript(sentence) { return sentence.filter(\.isLetter).count / 2 }
        return sentence.split(whereSeparator: \.isWhitespace).filter { $0.contains(where: \.isLetter) }.count
    }

    private static func hints(for preferred: [String]) -> [NLLanguage: Double] {
        var hints: [NLLanguage: Double] = [:]
        for code in preferred {
            guard let language = Locale.Language(identifier: code).languageCode?.identifier else { continue }
            hints[NLLanguage(rawValue: language)] = 0.25
        }
        return hints
    }
}
