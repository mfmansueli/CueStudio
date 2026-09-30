//
//  WordTokenizer.swift
//  Cue Studio
//

import Foundation

/// The one way Cue cuts text into words wherever speech is compared with writing: Voice Following
/// (the script and what's heard, `ScriptWords`), captions (`CaptionText`, `CaptionTranscriber`)
/// and Clean Up (`TimedWord.spoken`).
///
/// - Text written with spaces splits at anything that isn't a letter or a number, and an
///   apostrophe inside a word joins it ("don't"). English and Portuguese split exactly as they
///   always have.
/// - Runs of Japanese, Chinese, Thai… are split into dictionary words (`WordSegmenter`), in the
///   text's language when it's known, so a script and what's heard in it are cut the same way.
///   Digits in such a run are a word of their own ("3つ" is "3" and "つ").
/// - Matching (`key`) folds what recognition writes differently from a script: case, accents,
///   full and half width, Arabic letter forms and vowel marks, Hindi nukta dots; and
///   `matchingKeys` spells numbers out, so "3" and "three" are the same word.
nonisolated enum WordTokenizer {
    /// A word as written (letters and numbers only) and the character offset where it starts.
    struct Word: Equatable, Sendable {
        let text: String
        let offset: Int
    }

    /// Letters that join the letters around them into one word rather than split it.
    private static let joiners: Set<Character> = ["'", "\u{2019}", "\u{2018}"]

    /// The words of `text`, in order.
    static func words(in text: String, language: CueLanguage? = nil) -> [Word] {
        var result: [Word] = []
        var current = ""
        var start = 0
        func finish() {
            for piece in unspacedPieces(of: current, language: language) {
                result.append(Word(text: piece.word, offset: start + piece.offset))
            }
            current = ""
        }
        for (offset, character) in text.enumerated() {
            if character.isLetter || character.isNumber {
                if current.isEmpty { start = offset }
                current.append(character)
            } else if joiners.contains(character), !current.isEmpty {
                continue
            } else if !current.isEmpty {
                finish()
            }
        }
        if !current.isEmpty {
            finish()
        }
        return result
    }

    /// A run of letters split into words: whole when it's written with spaces; into dictionary
    /// words otherwise, with digits apart.
    private static func unspacedPieces(of run: String, language: CueLanguage?) -> [(word: String, offset: Int)] {
        guard WordSegmenter.containsUnspacedScript(run) else { return [(run, 0)] }
        var result: [(word: String, offset: Int)] = []
        var piece = ""
        var pieceStart = 0
        var pieceIsDigits = false
        func finishPiece() {
            guard !piece.isEmpty else { return }
            if pieceIsDigits {
                result.append((piece, pieceStart))
            } else {
                result += WordSegmenter.segments(of: piece, language: language).map { ($0.word, pieceStart + $0.offset) }
            }
            piece = ""
        }
        for (offset, character) in run.enumerated() {
            let isDigit = character.wholeNumberValue != nil
            if !piece.isEmpty, isDigit != pieceIsDigits { finishPiece() }
            if piece.isEmpty {
                pieceStart = offset
                pieceIsDigits = isDigit
            }
            piece.append(character)
        }
        finishPiece()
        return result
    }

    // MARK: - Matching

    /// A word as it's compared with speech: lowercased, without accents, in one width, with the
    /// letters recognition writes in more than one way folded to one. Empty for a word with no
    /// letters left, which never matches.
    static func key(_ word: String) -> String {
        let folded = word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
        var scalars = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            switch scalarFolds[scalar.value] {
            case .none: scalars.append(scalar)
            case .some(nil): continue
            case .some(let replacement?): scalars.append(replacement)
            }
        }
        return String(String(scalars).filter { $0.isLetter || $0.isNumber })
    }

    /// The keys a word is matched by: its `key`, or for a number written in digits, the number's
    /// words in `language` ("3" → "three", "três", "三"), so a script and a transcription match
    /// however each writes it. Without a language, numbers stay as written.
    static func matchingKeys(of word: String, language: CueLanguage?) -> [String] {
        let key = key(word)
        guard !key.isEmpty else { return [] }
        guard let language, let number = number(in: key) else { return [key] }
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = language.locale
        guard let spelled = formatter.string(from: NSNumber(value: number)) else { return [key] }
        let keys = words(in: spelled, language: language).map { Self.key($0.text) }.filter { !$0.isEmpty }
        return keys.isEmpty ? [key] : keys
    }

    /// Every matching key of `text`, in order.
    static func matchingKeys(in text: String, language: CueLanguage?) -> [String] {
        words(in: text, language: language).flatMap { matchingKeys(of: $0.text, language: language) }
    }

    /// Numbers spelled out stay short: bigger ones (years, prices) are read too many ways to help.
    private static let largestSpelledNumber = 9_999

    /// The value of a word made only of digits (in any script), up to `largestSpelledNumber`.
    private static func number(in key: String) -> Int? {
        guard key.count <= 4 else { return nil }
        var value = 0
        for character in key {
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
            value = value * 10 + digit
        }
        return value <= largestSpelledNumber ? value : nil
    }

    /// Letters folded before comparing, and marks dropped (nil). Recognition writes these without
    /// a fixed rule, and a script may too.
    private static let scalarFolds: [UInt32: Unicode.Scalar?] = {
        var folds: [UInt32: Unicode.Scalar?] = [:]
        func fold(_ scalar: UInt32, to replacement: UInt32?) {
            // `updateValue`, so a mark dropped (nil) is stored rather than removing the entry.
            folds.updateValue(replacement.flatMap(Unicode.Scalar.init), forKey: scalar)
        }
        // Arabic: alef with hamza or madda is written as a plain alef, taa marbuta as haa, alef
        // maqsura as yaa; vowel marks and the tatweel stretch are left out.
        for alef: UInt32 in [0x0622, 0x0623, 0x0625, 0x0671] { fold(alef, to: 0x0627) }
        fold(0x0629, to: 0x0647)
        fold(0x0649, to: 0x064A)
        fold(0x0640, to: nil)
        for mark: UInt32 in 0x064B...0x065F { fold(mark, to: nil) }
        fold(0x0670, to: nil)
        // Devanagari: letters with a nukta dot are heard as the letter without it, and
        // chandrabindu as anusvara.
        let nukta: [UInt32: UInt32] = [
            0x0958: 0x0915, 0x0959: 0x0916, 0x095A: 0x0917, 0x095B: 0x091C,
            0x095C: 0x0921, 0x095D: 0x0922, 0x095E: 0x092B, 0x095F: 0x092F,
        ]
        for (letter, base) in nukta { fold(letter, to: base) }
        fold(0x093C, to: nil)
        fold(0x0901, to: 0x0902)
        // Invisible joiners.
        fold(0x200C, to: nil)
        fold(0x200D, to: nil)
        return folds
    }()

    // MARK: - Display

    /// A caption line's words as shown: split at spaces, and text written without spaces into
    /// dictionary words, each keeping the punctuation that follows it ("今日は。" stays with its
    /// "。"), so lines still end on a sentence.
    static func displayWords(in line: String, language: CueLanguage? = nil) -> [String] {
        line.split(whereSeparator: \.isWhitespace).flatMap { piece -> [String] in
            let piece = String(piece)
            guard WordSegmenter.containsUnspacedScript(piece) else { return [piece] }
            let ranges = WordSegmenter.wordRanges(in: piece, language: language)
            guard !ranges.isEmpty else { return [piece] }
            var words: [String] = []
            var leading = String(piece[piece.startIndex..<ranges[0].lowerBound])
            for (index, range) in ranges.enumerated() {
                let end = index + 1 < ranges.count ? ranges[index + 1].lowerBound : piece.endIndex
                words.append(leading + String(piece[range.lowerBound..<end]))
                leading = ""
            }
            return words
        }
    }

    // MARK: - Clean Up

    /// A word as Clean Up compares it: lowercased and without punctuation, and a sound held long
    /// ("ummmm") the same as a short one ("umm"). Accents stay: Portuguese "é" (is) is a filler
    /// where "e" (and) never is.
    static func spokenForm(_ word: String) -> String {
        var result = ""
        var run = 0
        for character in word.lowercased() where character.isLetter || character.isNumber || character == "'" {
            run = character == result.last ? run + 1 : 1
            if run <= 2 { result.append(character) }
        }
        return result
    }
}
