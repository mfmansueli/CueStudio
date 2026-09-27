//
//  ScriptWords.swift
//  Cue Studio
//

import Foundation

/// The spoken words of a script in reading order, and where each one sits in the prompter text.
/// Voice follow matches what it hears against `tokens`, then scrolls to that word's position.
nonisolated struct ScriptWords: Equatable, Sendable {
    /// Where a word starts: its paragraph, and how far into that paragraph's text (0..<1).
    struct Location: Equatable, Sendable {
        let paragraph: Int
        let fraction: Double
    }

    /// Normalized words (see `tokens(in:)`). Cues are not spoken, so they are left out.
    let tokens: [String]
    let locations: [Location]

    var count: Int { tokens.count }

    /// Paragraphs are the same ones the prompter shows (`CueParser.paragraphs(in:)`).
    init(text: String) {
        var tokens: [String] = []
        var locations: [Location] = []
        for (index, paragraph) in CueParser.paragraphs(in: text).enumerated() {
            let spoken = CueParser.stripCues(paragraph)
            let length = Double(max(1, spoken.count))
            for word in Self.words(in: spoken) {
                tokens.append(word.token)
                locations.append(Location(paragraph: index, fraction: Double(word.offset) / length))
            }
        }
        self.tokens = tokens
        self.locations = locations
    }

    /// Lowercased words without accents or punctuation, so the script's "Você," matches a
    /// transcription's "voce". Apostrophes join ("don't" → "dont"); other symbols split.
    static func tokens(in text: String) -> [String] {
        words(in: text).map(\.token)
    }

    // MARK: - Positions

    /// Scroll offset that puts word `index` on the reading guide; the end once every word is read.
    /// Nil until the paragraph has been laid out.
    ///
    /// Lines are taken as evenly filled, so the offset glides through a paragraph as it's read and
    /// the line being read stays centered on the guide.
    /// - Parameter paragraphFrames: vertical extent of each paragraph in the text (top..<bottom).
    func offset(forWord index: Int, paragraphFrames: [Range<Double>], lineHeight: Double, endOffset: Double) -> Double? {
        guard index < count else { return endOffset }
        let location = locations[max(0, index)]
        guard paragraphFrames.indices.contains(location.paragraph), lineHeight > 0 else { return nil }
        let frame = paragraphFrames[location.paragraph]
        let height = frame.upperBound - frame.lowerBound
        let lines = max(1, (height / lineHeight).rounded())
        guard lines > 1 else { return min(endOffset, frame.lowerBound) }
        let line = min(lines - 1, max(0, location.fraction * lines - 0.5))
        return min(endOffset, frame.lowerBound + line * (height - lineHeight) / (lines - 1))
    }

    /// The first word at or past the guide at `offset`, to pick up from after a manual scroll.
    func wordIndex(atOffset offset: Double, paragraphFrames: [Range<Double>], lineHeight: Double, endOffset: Double) -> Int {
        tokens.indices.first { index in
            guard let wordOffset = self.offset(forWord: index, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: endOffset) else {
                return true
            }
            return wordOffset >= offset - 1
        } ?? count
    }

    // MARK: - Tokenizing

    private static let joiners: Set<Character> = ["'", "\u{2019}", "\u{2018}"]

    /// Each word with the character offset where it starts.
    private static func words(in text: String) -> [(token: String, offset: Int)] {
        var result: [(token: String, offset: Int)] = []
        var current = ""
        var start = 0
        for (offset, character) in text.enumerated() {
            if character.isLetter || character.isNumber {
                if current.isEmpty { start = offset }
                current.append(character)
            } else if joiners.contains(character), !current.isEmpty {
                continue
            } else if !current.isEmpty {
                result.append((normalized(current), start))
                current = ""
            }
        }
        if !current.isEmpty {
            result.append((normalized(current), start))
        }
        return result
    }

    private static func normalized(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
    }
}
