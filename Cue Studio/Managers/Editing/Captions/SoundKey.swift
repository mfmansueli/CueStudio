//
//  SoundKey.swift
//  Cue Studio
//

import Foundation

/// Words as they sound, roughly, so what a recognizer heard can be compared with the script when it wrote the same sounds as
/// other words: "Jean Carlos disse que ela" for "Giancarlo Fisichella", "yeşile gel" for "ve Schlegel", 普动 for 普通. Every
/// writing system is read in Latin letters first (Devanagari, Arabic, Thai, Hangul, kana; Chinese characters by their pinyin),
/// accents go, and the letters different languages write for one sound are folded to one. Only ever compared with itself:
/// it says how alike two stretches sound, never how a word is said.
nonisolated enum SoundKey {
    /// `words` as one run of sounds: Latin letters only, folded.
    static func of(_ words: [String]) -> String {
        folded(words.map(latinLetters).joined())
    }

    /// `word` in Latin letters, without accents, lowercased, letters only: the slow part of a key (the writing system's
    /// transliteration), worth keeping for a word compared in many stretches.
    static func latinLetters(_ word: String) -> String {
        let latin = word.applyingTransform(.toLatin, reverse: false) ?? word
        let plain = (latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin).lowercased()
        return String(plain.unicodeScalars.filter { ("a"..."z").contains($0) }.map(Character.init))
    }

    /// `letters` (from `latinLetters`) with the letters different languages write for one sound folded to one.
    static func folded(_ letters: String) -> String {
        var letters = letters
        for (spelling, sound) in digraphs {
            letters = letters.replacingOccurrences(of: spelling, with: sound)
        }
        var folded = ""
        for letter in letters {
            let sound = sounds[letter] ?? letter
            guard sound != "-", folded.last != sound else { continue }
            folded.append(sound)
        }
        return folded
    }

    /// How alike `heard` and `written` sound, 0 to 1 (`ScriptSpelling.ratio` of their keys).
    static func likeness(_ heard: [String], _ written: [String]) -> Double {
        ScriptSpelling.ratio(of(heard), of(written))
    }

    /// Spellings of one sound, read before single letters: "sch" before "ch" before "c".
    private static let digraphs: [(String, String)] = [
        ("sch", "s"), ("tch", "c"), ("ph", "f"), ("th", "t"), ("ch", "s"), ("sh", "s"), ("ck", "k"), ("qu", "k"), ("gh", "g"),
        ("ou", "u"),
    ]

    /// Letters folded to the sound they share across languages; "-" is dropped (an "h" is mostly silent or a breath).
    private static let sounds: [Character: Character] = [
        "y": "i", "w": "u", "c": "k", "q": "k", "z": "s", "v": "b", "j": "i", "h": "-", "x": "s",
    ]
}
