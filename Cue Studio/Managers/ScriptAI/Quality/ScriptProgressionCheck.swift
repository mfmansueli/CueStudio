//
//  ScriptProgressionCheck.swift
//  Cue Studio
//

import Foundation

/// Whether a script moves forward from block to block and keeps what its opening promised: the small model pads a block by saying the one before again,
/// and opens with "three mistakes" to tell two. Pure and cheap, run on every script; what it finds is counted (`GeneratedScript.progressionDefects`),
/// never acted on (a repair of the faulty block was tried on a device and made the script worse). The count of things promised is read in the
/// languages whose counting words it knows (English, Portuguese, Spanish); elsewhere only the repetition is checked.
nonisolated enum ScriptProgressionCheck {
    /// A block whose three-word runs were already said in earlier blocks at least this much is an echo.
    static let echoShare = 0.35
    /// Two sentences sharing this much of their meaningful words (at least `sentenceWords` of them) say the same thing.
    static let sentenceShare = 0.7
    static let sentenceWords = 4

    static func defects(in text: String, idea: String?, language: String?) -> [ProgressionDefect] {
        let blocks = ScriptExpansion.blocks(of: text)
        guard blocks.count >= 2 else { return [] }
        var found: [ProgressionDefect] = []
        for (index, echo) in ScriptRepetition.echoes(in: blocks, language: language).enumerated() where echo >= echoShare {
            found.append(ProgressionDefect(
                kind: .echo, block: index,
                detail: "Block \(index + 1) repeats what an earlier block already said: replace the repetition with a new point, example or step."
            ))
        }
        found += repeatedSentences(in: blocks, language: language).filter { defect in !found.contains { $0.block == defect.block } }
        if let unkept = unkeptCount(in: blocks, idea: idea, language: language) { found.append(unkept) }
        return found
    }

    /// What the script promised: the angle of an idea from Find inspiration, else the idea the creator typed.
    static func promiseSource(of request: ScriptRequest) -> String? {
        if let angle = request.brief?.angle, !angle.isEmpty { return angle }
        if case .prompt(let idea) = request.source { return idea }
        return nil
    }

    // MARK: - Sentences said twice

    private static func repeatedSentences(in blocks: [String], language: String?) -> [ProgressionDefect] {
        var said: [Set<String>] = []
        var found: [ProgressionDefect] = []
        for (index, block) in blocks.enumerated() {
            for sentence in WritingText.sentences(in: CueParser.stripCues(block), language: language) {
                let words = Set(IdeaFocus.words(in: sentence, language: language))
                guard words.count >= sentenceWords else { continue }
                if said.contains(where: { IdeaSimilarity.overlap($0, words) >= sentenceShare && min($0.count, words.count) >= sentenceWords }),
                   !found.contains(where: { $0.block == index }) {
                    found.append(ProgressionDefect(
                        kind: .repeatedSentence, block: index,
                        detail: "Block \(index + 1) says a sentence again that was already said: say something new instead."
                    ))
                }
                said.append(words)
            }
        }
        return found
    }

    // MARK: - The count promised

    /// The number of things the idea or the first sentence promises (two to ten), when it says one: "3 mistakes", "cinco passos", not "5 minutes".
    static func promisedCount(in text: String, language: String?) -> Int? {
        let words = folded(text)
        var numbers: [Int] = []
        for (index, word) in words.enumerated() {
            guard let value = Int(word).flatMap({ (2...10).contains($0) ? $0 : nil }) ?? numberWords[base(language)]?[word] else { continue }
            if index + 1 < words.count, units.contains(words[index + 1]) { continue }
            numbers.append(value)
        }
        return numbers.max()
    }

    /// How many things the script tells: its sentences that start by counting ("First", "Then", "Por fim", "Luego"), or its numbered items ("1.",
    /// "2)"), whichever is more; nil when it does neither (a script that tells its points without counting them can't be judged this way).
    static func toldCount(in blocks: [String], language: String?) -> Int? {
        guard let markers = sequenceMarkers[base(language)] else { return nil }
        let spoken = blocks.map(CueParser.stripCues)
        let counted = spoken.flatMap { WritingText.sentences(in: $0, language: language) }.filter { sentence in
            var words = folded(sentence)
            if let first = words.first, ["and", "e", "y"].contains(first) { words.removeFirst() }
            guard let first = words.first else { return false }
            let head = words.prefix(3).joined(separator: " ")
            return markers.contains { marker in
                head == marker || head.hasPrefix(marker + " ") || (!marker.contains(" ") && marker.count >= 5 && first.hasPrefix(marker))
            }
        }.count
        let numbered = Set(spoken.joined(separator: " ").matches(of: /(?:^|\s)([1-9])[.)]\s/).map { String($0.output.1) }).count
        let told = max(counted, numbered)
        return told == 0 ? nil : told
    }

    private static func folded(_ text: String) -> [String] {
        text.lowercased().folding(options: .diacriticInsensitive, locale: nil).split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Words after a number that make it a measure, not a count of things.
    private static let units: Set<String> = [
        "minutes", "minute", "min", "seconds", "hours", "days", "weeks", "months", "years", "times", "dollars", "euros", "kg", "percent",
        "minutos", "segundos", "horas", "dias", "semanas", "meses", "anos", "vezes", "reais", "dolares", "quilos", "por",
        "veces",
    ]

    private static func unkeptCount(in blocks: [String], idea: String?, language: String?) -> ProgressionDefect? {
        let opening = WritingText.sentences(in: CueParser.stripCues(blocks[0]), language: language).first ?? blocks[0]
        guard let promised = [idea.flatMap { promisedCount(in: $0, language: language) }, promisedCount(in: opening, language: language)]
            .compactMap({ $0 }).max(),
              let told = toldCount(in: Array(blocks.dropFirst()), language: language), told < promised else { return nil }
        return ProgressionDefect(
            kind: .unkeptCount, block: blocks.count - 1,
            detail: "The opening promises \(promised) things but the script tells \(told): tell all \(promised), one after another."
        )
    }

    private static func base(_ language: String?) -> String {
        String((language ?? "en").prefix(2))
    }

    private static let numberWords: [String: [String: Int]] = [
        "en": ["two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7],
        "pt": ["dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7],
        "es": ["dos": 2, "tres": 3, "cuatro": 4, "cinco": 5, "seis": 6, "siete": 7],
    ]

    /// The words a sentence starts with when it tells the next of several things, folded.
    private static let sequenceMarkers: [String: [String]] = [
        "en": ["first", "second", "third", "fourth", "fifth", "next", "then", "after that", "finally", "last", "lastly", "number one", "number two",
               "number three", "number four", "number five", "also",
        ],
        "pt": ["primeiro", "primeira", "segundo", "segunda", "terceiro", "terceira", "quarto", "quarta", "quinto", "quinta", "depois", "em seguida",
               "por fim", "por ultimo", "finalmente", "numero um", "numero dois", "numero tres", "alem disso", "tambem", "outro",
        ],
        "es": ["primero", "primera", "segundo", "segunda", "tercero", "tercera", "cuarto", "cuarta", "quinto", "quinta", "luego", "despues",
               "por ultimo", "finalmente", "numero uno", "numero dos", "numero tres", "ademas", "tambien", "otro",
        ],
    ]
}
