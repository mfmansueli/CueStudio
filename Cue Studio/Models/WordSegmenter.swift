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
    static func segments(of run: String) -> [(word: String, offset: Int)] {
        guard containsUnspacedScript(run) else { return [(run, 0)] }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = run
        var result: [(word: String, offset: Int)] = []
        tokenizer.enumerateTokens(in: run.startIndex..<run.endIndex) { range, _ in
            result.append((String(run[range]), run.distance(from: run.startIndex, to: range.lowerBound)))
            return true
        }
        return result.isEmpty ? [(run, 0)] : result
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
