//
//  ScriptVocabulary.swift
//  Cue Studio
//

import Foundation

/// The words of a script worth telling the recognizer about before it listens: names, brands and
/// long or unusual words, which it is most likely to mishear. It only biases what is heard toward
/// them (the voice still decides what was said), and it works in every language, since the words
/// come from the script as written.
nonisolated enum ScriptVocabulary {
    /// Most terms handed over.
    static let limit = 100
    /// Shortest word worth handing over.
    static let shortest = 4

    /// Distinct words of `script`, names (a capital inside a sentence) and long words first, in the
    /// order they appear otherwise. Cues, numbers and punctuation are left out.
    static func terms(in script: String, language: CueLanguage? = nil) -> [String] {
        let text = CueParser.stripCues(script)
        var seen = Set<String>()
        var ranked: [(term: String, score: Int, order: Int)] = []
        var startsSentence = true
        for word in CaptionText.words(in: text, language: language) {
            let term = word.trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespaces))
            let endsSentence = word.last.map { ".!?。！？…؟।".contains($0) } ?? false
            defer { startsSentence = endsSentence }
            let key = WordAlignment.key(term)
            guard term.count >= shortest, !term.contains(where: \.isNumber), seen.insert(key).inserted else { continue }
            var score = 0
            if !startsSentence, term.first?.isUppercase == true { score += 2 }
            if term.count >= 7 { score += 1 }
            ranked.append((term, score, ranked.count))
        }
        return ranked
            .sorted { ($0.score, -$0.order) > ($1.score, -$1.order) }
            .prefix(limit)
            .map(\.term)
    }
}
