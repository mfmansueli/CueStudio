//
//  WordSpans.swift
//  Cue Studio
//

import Foundation

/// Where one spoken word sits in a paragraph as the prompter draws it, and how many of the script's matching
/// tokens it stands for (a number spelled out is several).
nonisolated struct WordSpan: Equatable, Sendable {
    /// Character offsets in the drawn paragraph.
    let characters: Range<Int>
    let tokens: Int
}

/// The words of one paragraph in the drawn text, which has the `[cue]` tags in it (as ` CUE ` tags) or not.
/// Voice following lights the words as they are said, so it needs them where they are drawn.
nonisolated enum WordSpans {
    static func spans(in paragraph: String, showsCues: Bool, language: CueLanguage?) -> [WordSpan] {
        guard showsCues else { return spans(of: CueParser.stripCues(paragraph), base: 0, language: language) }
        var result: [WordSpan] = []
        var base = 0
        for segment in CueParser.segments(in: paragraph) {
            switch segment.kind {
            case .speech:
                result += spans(of: segment.text, base: base, language: language)
                base += segment.text.count
            case .cue:
                // Drawn as " TEXT " in narrow no-break spaces (`CueAttributedText`).
                base += segment.text.count + 2
            }
        }
        return result
    }

    private static func spans(of text: String, base: Int, language: CueLanguage?) -> [WordSpan] {
        let characters = Array(text)
        return WordTokenizer.words(in: text, language: language).map { word in
            // The tokenizer drops the apostrophes inside a word: the span runs to the end of the run.
            var end = word.offset
            while end < characters.count, characters[end].isLetter || characters[end].isNumber || isJoiner(characters[end]) { end += 1 }
            end = max(end, word.offset + 1)
            let tokens = max(1, WordTokenizer.matchingKeys(of: word.text, language: language).count)
            return WordSpan(characters: (base + word.offset)..<(base + min(end, characters.count)), tokens: tokens)
        }
    }

    private static func isJoiner(_ character: Character) -> Bool {
        character == "'" || character == "\u{2019}" || character == "\u{2018}"
    }
}

/// What the prompter lights: words read up to `position` (a token index in the whole script), the last few lit
/// and the newest in the accent colour; everything else at rest.
nonisolated struct WordHighlight: Equatable, Sendable {
    /// Token index of the next word to read.
    var position: Int
    /// Per paragraph: its words.
    var spans: [[WordSpan]]
    /// Per paragraph: the token index where it starts.
    var starts: [Int]

    /// How many words behind the newest stay lit: about the line being read.
    static let litWords = 7

    /// The paragraph being read: the one that holds the token before `position`, or the first one at the start.
    var currentParagraph: Int {
        let anchor = max(0, position - 1)
        return starts.lastIndex { $0 <= anchor } ?? 0
    }

    /// The words of `paragraph` that are lit and the newest one, as indices into its spans. Nil for a paragraph
    /// that is all at rest (read earlier or not reached).
    func lit(in paragraph: Int) -> (words: Range<Int>, newest: Int?)? {
        guard paragraph == currentParagraph, spans.indices.contains(paragraph), starts.indices.contains(paragraph) else { return nil }
        let local = position - starts[paragraph]
        var read = 0
        var tokens = 0
        for span in spans[paragraph] {
            guard tokens + span.tokens <= local else { break }
            tokens += span.tokens
            read += 1
        }
        guard read > 0 else { return nil }
        return (max(0, read - Self.litWords)..<read, read - 1)
    }
}
