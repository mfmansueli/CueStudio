//
//  PromptCost.swift
//  Cue Studio
//

import Foundation

/// What a text costs the model, in "characters of English": the same measure the voice budget (`VoiceBrief.budget`) is in. The model's window is
/// 4096 tokens shared by the instructions, the voice, the idea and the script it writes, and the same number of characters is very different
/// tokens in different scripts (measured on an iPhone 15 Pro: 0.21 tokens a character in English, 0.52 in Japanese, 0.78 in Chinese), so a limit
/// in plain characters is loose for English and tight, or too loose, for everyone else. A letter of a Latin script counts as 1, and every other
/// script as many as its tokens are to those of Latin (`PaletteContrastTests`-style: the weights are checked against the measured numbers in
/// `PromptCostTests`). Cheap enough to run on every keystroke of the "What Cue sends" meter.
nonisolated enum PromptCost {
    /// Thousandths of a token a character of Latin text takes, with room to spare (English prose is 0.21, the brief with its quotes and dashes 0.31).
    private static let latin = 300

    /// The thousandths of a token a character of each script takes, as the iPhone's tokenizer was measured (rounded up). Whole numbers, so that
    /// English costs exactly its characters.
    private static func milliTokens(of scalar: Unicode.Scalar) -> Int {
        switch scalar.value {
        case 0x0000...0x024F, 0x1E00...0x1EFF, 0x2000...0x206F: latin                       // Latin, with its accents and the usual punctuation
        case 0x0370...0x058F: 400                                                            // Greek, Cyrillic, Armenian
        case 0x0590...0x06FF, 0x0750...0x077F, 0xFB1D...0xFDFF, 0xFE70...0xFEFF: 360         // Hebrew, Arabic
        case 0x0900...0x0DFF: 400                                                            // Devanagari and the other scripts of India
        case 0x0E00...0x0E7F: 430                                                            // Thai
        case 0x1100...0x11FF, 0x3130...0x318F, 0xAC00...0xD7AF: 540                          // Hangul
        case 0x3040...0x30FF: 520                                                            // Hiragana and katakana
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FFFF: 780       // Han
        default: 500                                                                         // symbols, emoji, anything else
        }
    }

    /// The cost of `text` in characters of English.
    static func units(of text: String) -> Int {
        let milli = text.unicodeScalars.reduce(0) { $0 + milliTokens(of: $1) }
        return (milli + latin - 1) / latin
    }

    /// The tokens `text` is estimated to take.
    static func tokens(of text: String) -> Int {
        (text.unicodeScalars.reduce(0) { $0 + milliTokens(of: $1) } + 999) / 1000
    }

    /// `text` cut at a word so that it costs at most `units`, with an ellipsis; as it is when it fits. Never empty unless `units` is under one.
    static func shortened(_ text: String, toUnits limit: Int) -> String {
        guard units(of: text) > limit else { return text }
        var characters = text.count
        // The cost is nearly proportional to the length: aim for the ratio, then step back until it fits.
        characters = max(1, Int(Double(characters) * Double(limit) / Double(units(of: text))))
        var cut = String(text.prefix(characters))
        while characters > 1, units(of: cut + "…") > limit {
            characters -= max(1, characters / 20)
            cut = String(text.prefix(characters))
        }
        let atWord = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? cut
        return atWord.trimmingCharacters(in: CharacterSet(charactersIn: ",;:.— ")) + "…"
    }
}
