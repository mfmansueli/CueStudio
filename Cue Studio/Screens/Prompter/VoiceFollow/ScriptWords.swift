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

    /// Matching keys of the words (see `tokens(in:language:)`). Cues are not spoken, so they are
    /// left out.
    let tokens: [String]
    let locations: [Location]
    /// Per paragraph, the index of its first token; one more at the end, so a paragraph's tokens are
    /// `starts[i]..<starts[i + 1]`.
    let paragraphStarts: [Int]

    var count: Int { tokens.count }

    /// Paragraphs are the same ones the prompter shows (`CueParser.paragraphs(in:)`).
    /// - Parameter language: the language it's read in, so words are cut and numbers spelled the
    ///   way the transcription's will be.
    init(text: String, language: CueLanguage? = nil) {
        var tokens: [String] = []
        var locations: [Location] = []
        var starts: [Int] = []
        for (index, paragraph) in CueParser.paragraphs(in: text).enumerated() {
            starts.append(tokens.count)
            let spoken = CueParser.stripCues(paragraph)
            let length = Double(max(1, spoken.count))
            for word in WordTokenizer.words(in: spoken, language: language) {
                // A number spelled out is several words at the number's place.
                for key in WordTokenizer.matchingKeys(of: word.text, language: language) {
                    tokens.append(key)
                    locations.append(Location(paragraph: index, fraction: Double(word.offset) / length))
                }
            }
        }
        self.tokens = tokens
        self.locations = locations
        paragraphStarts = starts + [tokens.count]
    }

    /// Lowercased words without accents or punctuation, so the script's "Você," matches a
    /// transcription's "voce". Apostrophes join ("don't" → "dont"); other symbols split. Cut and
    /// folded by `WordTokenizer`, the same as captions and Clean Up.
    static func tokens(in text: String, language: CueLanguage? = nil) -> [String] {
        WordTokenizer.matchingKeys(in: text, language: language)
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

    /// The offset for a position between words (`3.4` is 40% of the way from the fourth word to
    /// the fifth), for a text running a little ahead of the last word heard.
    func offset(forPosition position: Double, paragraphFrames: [Range<Double>], lineHeight: Double, endOffset: Double) -> Double? {
        let word = Int(position.rounded(.down))
        guard let from = offset(forWord: word, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: endOffset) else {
            return nil
        }
        let fraction = position - Double(word)
        guard fraction > 0,
              let to = offset(forWord: word + 1, paragraphFrames: paragraphFrames, lineHeight: lineHeight, endOffset: endOffset) else {
            return from
        }
        return from + (to - from) * fraction
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
}
