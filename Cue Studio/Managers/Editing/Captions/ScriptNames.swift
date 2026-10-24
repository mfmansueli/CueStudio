//
//  ScriptNames.swift
//  Cue Studio
//

import Foundation

/// The names in a script, read from how it is written: a word with a capital inside it, as brands are ("iPhone", "TikTok",
/// "USAs"); a capitalized word inside a sentence, or one starting a sentence before another ("Giancarlo Fisichella perdeu");
/// and a word in Latin letters in a script written in another alphabet ("Scotturb" in Chinese). German capitalizes every noun,
/// so there only a capital inside a word counts; Arabic, Hindi, Chinese, Japanese, Korean and Thai have no capitals to tell
/// names by.
/// Recognizers mishear names more than any other word, and a creator reading a script says them as written, so they are the
/// words the script may lend even when the recognizer wrote others for them. (Natural Language's name tagger was tried: on an
/// iOS 27 simulator it found nothing in some languages until its model happened to be loaded, and preparing the model hung.)
nonisolated enum ScriptNames {
    /// The `WordAlignment.key`s of the names in `script`, written in `language`.
    static func keys(in script: String, language: CueLanguage?) -> Set<String> {
        let words = CueParser.stripCues(script).split(whereSeparator: \.isWhitespace).map(String.init)
        let capitalsMarkNames = language != .german && !(language.map(writesOtherAlphabet) ?? false)
        var keys = Set<String>()
        var startsSentence = true
        for (index, word) in words.enumerated() {
            defer { startsSentence = word.last.map { ".!?。！？…؟।:".contains($0) } ?? false }
            let letters = word.drop { !$0.isLetter }
            guard let first = letters.first else { continue }
            let key = WordAlignment.key(word)
            if letters.dropFirst().contains(where: \.isUppercase) || (language.map(writesOtherAlphabet) ?? false) && isLatin(first) {
                keys.insert(key)
            } else if capitalsMarkNames, first.isUppercase {
                let nextIsCapitalized = index + 1 < words.count && words[index + 1].first(where: \.isLetter)?.isUppercase == true
                if !startsSentence || nextIsCapitalized { keys.insert(key) }
            }
        }
        keys.remove("")
        return keys
    }

    /// Whether `language` is written in an alphabet other than Latin letters.
    private static func writesOtherAlphabet(_ language: CueLanguage) -> Bool {
        switch language {
        case .japanese, .chineseSimplified, .chineseTraditional, .korean, .arabic, .hindi, .thai: true
        default: false
        }
    }

    private static func isLatin(_ letter: Character) -> Bool {
        letter.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || (0xC0...0x24F).contains($0.value) }
    }
}
