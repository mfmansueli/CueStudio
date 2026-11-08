//
//  CaptionEmphasisSuggester.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Suggest emphasis's rule, on the device and the same on every iPhone (owner, 08/11/2026): in a line of three words or more, at
/// most one word, and only when the line has a clear one. Numbers, values and names are signals, never marked just for being there:
/// - a **value** (a number with money, a percent, a "3x" or a "5 mil") is the line's word when it is the only value in it;
/// - with no value, a **number** or a one-word **name** (people, places, organizations) is the word when it is the only one;
/// - two of a kind ("25 to 30 years", two names), a name cut by the line's end, or nothing to go on leaves the line without a mark.
/// Incidental numbers are never signals: times (9:30, 7h), dates (08/11), years (2019), ordinals (1st, 2º) and numbers that only
/// name a step, a page or a part ("step 1", "parte 2").
nonisolated enum CaptionEmphasisSuggester {
    /// Lines shorter than this have no word to single out.
    static let shortestLine = 3

    /// The word of `text` (its place among `CaptionText.words(in:)`) worth emphasis, or nil.
    static func suggestion(in text: String, language: NLLanguage? = nil) -> Int? {
        let words = CaptionText.words(in: text)
        guard words.count >= shortestLine else { return nil }
        let bare = words.map(Self.bare)
        var values: [Int] = []
        var numbers: [Int] = []
        for (index, word) in bare.enumerated() where word.contains(where: \.isNumber) {
            guard !isIncidental(word, after: index > 0 ? bare[index - 1] : nil) else { continue }
            let next = index + 1 < bare.count ? bare[index + 1] : nil
            let previous = index > 0 ? bare[index - 1] : nil
            if isValue(word, previous: previous, next: next) { values.append(index) } else if isPlainNumber(word) { numbers.append(index) }
        }
        if !values.isEmpty { return values.count == 1 ? values[0] : nil }
        let signals = numbers + names(in: text, words: bare, language: language).filter { !numbers.contains($0) }
        return signals.count == 1 ? signals[0] : nil
    }

    /// Suggestions for `lines`, by line: none for a line with marks of the creator's, with a suggestion taken away, or already
    /// suggested.
    static func suggestions(for lines: [CaptionCue], language: NLLanguage?) -> [UUID: Int] {
        var found: [UUID: Int] = [:]
        for line in lines where line.ownEmphasis.isEmpty && line.declinedEmphasis.isEmpty && line.suggestedEmphasis.isEmpty {
            if let index = suggestion(in: line.text, language: language) { found[line.id] = index }
        }
        return found
    }

    // MARK: - Signals

    private static let currencySymbols: Set<Character> = ["$", "€", "£", "¥", "₹", "₩", "₺", "฿"]
    private static let currencyWords: Set<String> = [
        "r$", "us$", "usd", "brl", "eur", "reais", "real", "dólar", "dólares", "dolar", "dolares", "dollar", "dollars", "bucks",
        "euro", "euros", "libras", "pounds", "pesos", "centavos", "cents",
    ]
    private static let percentWords: Set<String> = ["%", "percent", "per", "por", "porcento", "pct"]
    private static let magnitudeWords: Set<String> = [
        "k", "mil", "mi", "milhão", "milhões", "bi", "bilhão", "bilhões", "thousand", "million", "millions", "billion", "billions",
    ]
    /// Words before a number that only names or times something ("step 1", "parte 2", "às 7", "at 9").
    private static let namingWords: Set<String> = [
        "step", "page", "part", "chapter", "episode", "number", "no", "nº", "#", "level", "season", "day", "round", "tip", "item", "at",
        "passo", "página", "pagina", "parte", "capítulo", "capitulo", "episódio", "episodio", "número", "numero", "nível", "nivel",
        "temporada", "dia", "rodada", "dica", "às", "as",
    ]

    private static func isValue(_ word: String, previous: String?, next: String?) -> Bool {
        let lower = word.lowercased()
        if word.contains(where: currencySymbols.contains) || lower.hasPrefix("r$") { return true }
        if word.hasSuffix("%") { return true }
        if lower.range(of: #"^\d+([.,]\d+)?(x|k|mil|mi|m|bi)$"#, options: .regularExpression) != nil { return true }
        guard isPlainNumber(word) else { return false }
        if let previous, currencyWords.contains(previous.lowercased()) || previous.allSatisfy(currencySymbols.contains) { return true }
        guard let next = next?.lowercased() else { return false }
        return currencyWords.contains(next) || percentWords.contains(next) || magnitudeWords.contains(next)
    }

    private static func isPlainNumber(_ word: String) -> Bool {
        word.range(of: #"^\d+([.,]\d+)*$"#, options: .regularExpression) != nil
    }

    private static func isIncidental(_ word: String, after previous: String?) -> Bool {
        let lower = word.lowercased()
        // 9:30, 7h, 7h30
        if lower.range(of: #"^\d{1,2}(:\d{2}|h\d{0,2})$"#, options: .regularExpression) != nil { return true }
        // 08/11, 8/11/2026, 2026-11-08
        if lower.range(of: #"^\d{1,4}[/-]\d{1,2}([/-]\d{1,4})?$"#, options: .regularExpression) != nil { return true }
        // 1st, 2nd, 3rd, 4th, 2º, 1ª, 2o
        if lower.range(of: #"^\d+(st|nd|rd|th|º|ª|o|a)$"#, options: .regularExpression) != nil { return true }
        // A year.
        if lower.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil { return true }
        if let previous, isPlainNumber(word), namingWords.contains(previous.lowercased()) { return true }
        return false
    }

    /// One-word names in the line (two-word names, "São Paulo", have no single word to mark).
    private static func names(in text: String, words: [String], language: NLLanguage?) -> [Int] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        if let language { tagger.setLanguage(language, range: text.startIndex..<text.endIndex) }
        var found: [Int] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            guard let tag, [.personalName, .placeName, .organizationName].contains(tag) else { return true }
            let name = String(text[range])
            guard !name.contains(where: \.isWhitespace), let index = words.firstIndex(of: bare(name)), !found.contains(index) else { return true }
            // The first word of a line is capitalized anyway, and a last word with nothing after it may go on in the next line
            // ("Reino | Unido"): a name there is only a guess.
            let goesOn = index == words.count - 1 && !(text.trimmingCharacters(in: .whitespaces).last?.isPunctuation ?? false)
            if index > 0, !goesOn { found.append(index) }
            return true
        }
        return found
    }

    /// A word without the punctuation around it ("cada," → "cada", "(25)" → "25"); money and percent signs stay.
    static func bare(_ word: String) -> String {
        let edges = CharacterSet.punctuationCharacters.union(.symbols).subtracting(CharacterSet(charactersIn: "%$€£¥₹₩₺฿#"))
        return word.trimmingCharacters(in: edges.union(.whitespaces))
    }
}
