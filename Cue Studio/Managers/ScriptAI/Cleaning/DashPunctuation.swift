//
//  DashPunctuation.swift
//  Cue Studio
//

import Foundation

/// What a language writes where the model put a dash (`DashRewriter`): its comma, colon and full stop, whether it has capitals and spaces
/// between words, and the words that start a clause going on from the one before ("until", "até", "bis"), after which a comma is enough.
nonisolated struct DashPunctuation: Equatable, Sendable {
    /// The language code the table is for ("en", "zh"…).
    let code: String
    /// Each mark with the space that follows it, where the language puts one.
    let comma: String
    let colon: String
    let fullStop: String
    /// Chinese, Japanese and Thai: no spaces between words, so a clause is measured in characters.
    let isUnspaced: Bool
    /// A sentence the rewriter starts begins with a capital.
    let hasCase: Bool
    /// Japanese prose seldom takes a colon: a short head before a dash gets a comma, and only a list a colon.
    let colonInProse: Bool
    /// Arabic chains clauses with commas: two clauses joined by a dash are never cut into two sentences.
    let splitsSentences: Bool
    /// Words (or two-word phrases) that start a clause continuing the one before. Arabic attaches its own (و, ف) to the next word, so it has none.
    let connectors: Set<String>
    /// "and", "or": before the last item of a list.
    let listWords: Set<String>

    /// The marks of `language`; English's for a language Cue doesn't write or none.
    static func forLanguage(_ language: Locale.Language?) -> DashPunctuation {
        let code = language?.languageCode?.identifier ?? "en"
        let words = Self.words[code] ?? Self.words["en"] ?? (connectors: [], list: [])
        switch code {
        case "zh":
            return DashPunctuation(code: code, comma: "，", colon: "：", fullStop: "。", unspaced: true, words: words)
        case "ja":
            return DashPunctuation(code: code, comma: "、", colon: "：", fullStop: "。", unspaced: true, colonInProse: false, words: words)
        case "th":
            // Thai separates clauses with a space and has no comma or colon in running text.
            return DashPunctuation(code: code, comma: " ", colon: " ", fullStop: " ", unspaced: true, words: words)
        case "ar":
            return DashPunctuation(code: code, comma: "، ", colon: ": ", fullStop: ". ", hasCase: false, splitsSentences: false, words: words)
        case "hi":
            return DashPunctuation(code: code, comma: ", ", colon: ": ", fullStop: "। ", hasCase: false, words: words)
        case "ko":
            return DashPunctuation(code: code, comma: ", ", colon: ": ", fullStop: ". ", hasCase: false, words: words)
        case "fr":
            // French puts a narrow no-break space before the colon.
            return DashPunctuation(code: code, comma: ", ", colon: "\u{202F}: ", fullStop: ". ", words: words)
        default:
            return DashPunctuation(code: code, comma: ", ", colon: ": ", fullStop: ". ", words: words)
        }
    }

    private init(
        code: String, comma: String, colon: String, fullStop: String, unspaced: Bool = false, hasCase: Bool? = nil, colonInProse: Bool = true,
        splitsSentences: Bool = true, words: (connectors: Set<String>, list: Set<String>)
    ) {
        self.code = code
        self.comma = comma
        self.colon = colon
        self.fullStop = fullStop
        isUnspaced = unspaced
        self.hasCase = hasCase ?? !unspaced
        self.colonInProse = colonInProse
        self.splitsSentences = splitsSentences
        connectors = words.connectors
        listWords = words.list
    }

    /// The full stop for a sentence that ends with `terminator`: Hindi written with Latin full stops keeps them, and the danda otherwise.
    func fullStop(inSentenceEndingWith terminator: Character?) -> String {
        code == "hi" && terminator == "." ? ". " : fullStop
    }

    /// `word` (lowercased, its punctuation trimmed) or the two words starting the clause continue the clause before.
    func isConnector(firstWords words: [String]) -> Bool {
        guard let first = words.first else { return false }
        if isUnspaced { return connectors.contains { first.hasPrefix($0) } }
        return connectors.contains(first) || (words.count > 1 && connectors.contains(words[0] + " " + words[1]))
    }

    /// The connectors and list words of each language Cue writes.
    private static let words: [String: (connectors: Set<String>, list: Set<String>)] = [
        "en": (["and", "but", "so", "or", "until", "because", "then", "which", "while", "though", "yet"], ["and", "or"]),
        "pt": (["e", "mas", "então", "até", "porque", "que", "ou", "pois"], ["e", "ou"]),
        "es": (["y", "pero", "así que", "hasta", "porque", "que", "o", "pues"], ["y", "o"]),
        "fr": (["et", "mais", "donc", "jusqu’à", "jusqu'à", "parce que", "ou", "car", "puis"], ["et", "ou"]),
        "de": (["und", "aber", "also", "bis", "weil", "denn", "oder", "dann"], ["und", "oder"]),
        "it": (["e", "ma", "quindi", "finché", "perché", "o", "poi"], ["e", "o"]),
        "nl": (["en", "maar", "dus", "tot", "want", "of", "dan"], ["en", "of"]),
        "sv": (["och", "men", "så", "tills", "eller", "för"], ["och", "eller"]),
        "da": (["og", "men", "så", "indtil", "eller", "for"], ["og", "eller"]),
        "nb": (["og", "men", "så", "til", "eller", "for"], ["og", "eller"]),
        "tr": (["ve", "ama", "ta ki", "çünkü", "yoksa", "sonra"], ["ve", "veya"]),
        "id": (["dan", "tapi", "tetapi", "jadi", "sampai", "karena", "atau"], ["dan", "atau"]),
        "vi": (["và", "nhưng", "nên", "vì"], ["và", "hoặc"]),
        "ko": (["그리고", "하지만", "그래서", "그런데"], ["그리고"]),
        "hi": (["और", "लेकिन", "पर", "तो", "क्योंकि"], ["और", "या"]),
        "zh": (["但是", "所以", "而且", "然后", "然後", "因为", "因為", "直到"], []),
        "ja": (["でも", "だから", "そして", "けど"], []),
        "th": ([], []),
        "ar": ([], []),
    ]
}
