//
//  WordSegmenter.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Words in languages written without spaces between them (Japanese, Chinese, Thai…), found with
/// the system's dictionaries. Text with spaces never goes through here, so how English or
/// Portuguese is split doesn't change.
nonisolated enum WordSegmenter {
    /// Letters of a script that doesn't separate words with spaces.
    static func isUnspaced(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3005...0x3007, // 々 〆 〇
             0x3040...0x30FF, // Hiragana, Katakana
             0x31F0...0x31FF, // Katakana extensions
             0x3400...0x4DBF, // Han extension A
             0x4E00...0x9FFF, // Han
             0xF900...0xFAFF, // Han compatibility
             0xFF66...0xFF9F, // Half-width Katakana
             0x20000...0x2FA1F, // Han extensions B–F, supplement
             0x0E00...0x0E7F, // Thai
             0x0E80...0x0EFF, // Lao
             0x1000...0x109F, // Myanmar
             0x1780...0x17FF: // Khmer
            true
        default:
            false
        }
    }

    static func containsUnspacedScript(_ text: some StringProtocol) -> Bool {
        text.unicodeScalars.contains(where: isUnspaced)
    }

    /// Splits a run of letters into words, each with the character offset where it starts in `run`.
    /// A run without unspaced letters is one word.
    /// - Parameter language: the text's language when it's known, so a script and what's heard in
    ///   it are cut with the same dictionary (a few kanji alone could otherwise be read as Chinese).
    static func segments(of run: String, language: CueLanguage? = nil) -> [(word: String, offset: Int)] {
        guard containsUnspacedScript(run) else { return [(run, 0)] }
        let result = wordRanges(in: run, language: language).map { range in
            (String(run[range]), run.distance(from: run.startIndex, to: range.lowerBound))
        }
        return result.isEmpty ? [(run, 0)] : result
    }

    /// Where each dictionary word of `text` is. Punctuation and spaces are left between them.
    static func wordRanges(in text: String, language: CueLanguage? = nil) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language { tokenizer.setLanguage(naturalLanguage(for: language)) }
        var result: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            result.append(range)
            return true
        }
        return result
    }

    private static func naturalLanguage(for language: CueLanguage) -> NLLanguage {
        switch language {
        case .chineseSimplified: .simplifiedChinese
        case .chineseTraditional: .traditionalChinese
        default: NLLanguage(rawValue: language.languageCode)
        }
    }

    /// How many words `text` has: runs of letters and numbers, with unspaced runs split into words.
    static func wordCount(in text: String) -> Int {
        var count = 0
        var run = ""
        func finish() {
            guard !run.isEmpty else { return }
            count += segments(of: run).count
            run = ""
        }
        for character in text {
            if character.isLetter || character.isNumber {
                run.append(character)
            } else {
                finish()
            }
        }
        finish()
        return count
    }
}
