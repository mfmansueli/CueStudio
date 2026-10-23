//
//  TextShaping.swift
//  Cue Studio
//

import Foundation
import os

/// What every writing system survives when Cue draws words on a video: letters spaced out only where they stand apart, and
/// capitals as the language writes them.
nonisolated enum TextShaping {
    /// Whether letters can be spaced out: not in scripts whose letters join (Arabic, Syriac, Thaana, N'Ko, Mongolian) or stack
    /// and combine (Devanagari and the other Indic scripts, Sinhala, Thai, Lao, Tibetan, Myanmar, Khmer), where added space
    /// breaks the writing apart.
    static func allowsLetterSpacing(in text: String) -> Bool {
        !text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x07FF, 0x0860...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF: true // Arabic, Syriac, Thaana, N'Ko
            case 0x0900...0x0DFF: true // Devanagari … Sinhala
            case 0x0E00...0x0FFF, 0x1000...0x109F, 0x1780...0x18AF: true // Thai, Lao, Tibetan, Myanmar, Khmer, Mongolian
            default: false
            }
        }
    }

    /// Writing systems whose letters join or stack (ISO 15924), for a language rather than a text: the interface's labels.
    private static let joinedScripts: Set<String> = [
        "Arab", "Syrc", "Thaa", "Nkoo", "Mong", "Deva", "Beng", "Guru", "Gujr", "Orya", "Taml", "Telu", "Knda", "Mlym", "Sinh",
        "Thai", "Laoo", "Tibt", "Mymr", "Khmr",
    ]

    /// Whether `language`'s letters can be spaced out (`allowsLetterSpacing(in:)`, for a label whose words aren't known yet).
    static func allowsLetterSpacing(in language: Locale.Language) -> Bool {
        let script = Locale.Language(identifier: language.maximalIdentifier).script?.identifier
        return script.map { !joinedScripts.contains($0) } ?? true
    }

    /// `text` in capitals, as its language writes them: Turkish and Azerbaijani "i" becomes "İ", never "I".
    static func uppercased(_ text: String) -> String {
        uppercased(text, locale: capitalsLocale(for: text))
    }

    /// One piece of `line` in the capitals the whole line is written in (`capitalsLocale(for: line)`).
    static func uppercased(_ text: String, locale: Locale?) -> String {
        if let locale { return text.uppercased(with: locale) }
        return text.uppercased()
    }

    /// The language whose capitals differ from everyone else's, when `text` is in one and has a letter they change; nil
    /// writes them the usual way. Read from the text once and remembered (drawing asks for every frame).
    static func capitalsLocale(for text: String) -> Locale? {
        guard text.contains("i") else { return nil }
        if let known = remembered.withLock({ $0[text] }) { return known.map(Locale.init(identifier:)) }
        let code = LanguageDetector.dominantLanguageCode(in: text).flatMap { dottedILanguages.contains($0) ? $0 : nil }
        remembered.withLock { cache in
            if cache.count >= 512 { cache.removeAll() }
            cache[text] = .some(code)
        }
        return code.map(Locale.init(identifier:))
    }

    /// Languages whose "i" keeps its dot as a capital ("İ").
    private static let dottedILanguages: Set<String> = ["tr", "az"]

    private static let remembered = OSAllocatedUnfairLock<[String: String?]>(initialState: [:])
}
