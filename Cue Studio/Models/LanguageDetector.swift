//
//  LanguageDetector.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// The language a text is written in, read from the text itself (Natural Language, on the device).
/// Scripts set to Auto-detect use it. It detects written text only: there is no reliable way to
/// tell the language someone is speaking before recognizing it, so Voice Following never guesses
/// that.
nonisolated enum LanguageDetector {
    /// ISO 639 code of the dominant language ("pt", "ja"), or nil when there's nothing to tell by.
    /// Cues aren't spoken, so they don't count.
    static func dominantLanguageCode(in text: String) -> String? {
        let spoken = CueParser.stripCues(text)
        guard spoken.contains(where: { $0.isLetter }) else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(spoken)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return Locale.Language(identifier: language.rawValue).languageCode?.identifier
    }

    /// The detected language when Cue offers it.
    static func language(in text: String) -> CueLanguage? {
        dominantLanguageCode(in: text).flatMap(CueLanguage.matching(languageCode:))
    }
}
