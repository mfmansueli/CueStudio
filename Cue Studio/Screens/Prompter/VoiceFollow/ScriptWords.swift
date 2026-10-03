//
//  ScriptWords.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

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
    /// transcription's "voce". Apostrophes join ("don't" → "dont"); other symbols split. Japanese,
    /// Chinese and Thai, written without spaces, are split into words by the system's tokenizer.
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
                result += split(current, at: start)
                current = ""
            }
        }
        if !current.isEmpty {
            result += split(current, at: start)
        }
        return result
    }

    /// A run of letters is one word, except in scripts written without spaces between words: there
    /// the run is a whole phrase, so it is cut into words. The script and what's heard go through
    /// the same cut, so their words line up.
    private static func split(_ run: String, at start: Int) -> [(token: String, offset: Int)] {
        guard run.unicodeScalars.contains(where: isUnspacedScript) else {
            return [(normalized(run), start)]
        }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = run
        var pieces: [(token: String, offset: Int)] = []
        tokenizer.enumerateTokens(in: run.startIndex..<run.endIndex) { range, _ in
            let offset = start + run.distance(from: run.startIndex, to: range.lowerBound)
            pieces.append((normalized(String(run[range])), offset))
            return true
        }
        return pieces.isEmpty ? [(normalized(run), start)] : pieces
    }

    /// Han, Hiragana, Katakana, Thai, Lao, Khmer and Myanmar: scripts that don't put spaces between
    /// words.
    private static func isUnspacedScript(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9F: true // Hiragana, Katakana
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F: true // Han
        case 0x0E00...0x0E7F, 0x0E80...0x0EFF: true // Thai, Lao
        case 0x1780...0x17FF, 0x1000...0x109F: true // Khmer, Myanmar
        default: false
        }
    }

    private static func normalized(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
    }
}
