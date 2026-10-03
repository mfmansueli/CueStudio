//
//  SpeechLocaleResolver.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Turns a `SpeechLanguageRequest` into the locales to try with Apple's speech framework, best
/// first. Which of them the device actually supports is asked of the framework
/// (`SpeechRecognitionManager`); nothing here assumes a language works.
nonisolated enum SpeechLocaleResolver {
    /// Locales to try, best first.
    /// - A picked language: the creator's own region when their iPhone lists one and the language
    ///   allows it (English in the UK), then Cue's default for it ("pt-BR", "en-US").
    /// - Detected from the script: what Voice Following always tried (the creator's region, then the
    ///   bare language), with Cue's default for the language in between so Portuguese on an Italian
    ///   iPhone listens in Brazilian Portuguese. Without a clear language, the device's.
    static func candidates(
        for request: SpeechLanguageRequest,
        detectedLanguageCode: String?,
        preferredLanguages: [String] = Locale.preferredLanguages,
        current: Locale = .current
    ) -> [Locale] {
        switch request {
        case .language(let language):
            var candidates: [Locale] = []
            if !language.keepsRegionForSpeech {
                candidates += regional(language.languageCode, in: preferredLanguages)
            }
            candidates.append(language.locale)
            return unique(candidates)
        case .detectFromScript:
            guard let code = detectedLanguageCode else { return [current] }
            var candidates = regional(code, in: preferredLanguages)
            if let language = CueLanguage(identifier: code) {
                candidates.append(language.locale)
            }
            candidates.append(Locale(identifier: code))
            return unique(candidates)
        }
    }

    /// The Cue language a request listens in, when it names one Cue knows. Used for messages and to
    /// lay out right-to-left scripts.
    static func language(for request: SpeechLanguageRequest, detectedLanguageCode: String?) -> CueLanguage? {
        switch request {
        case .language(let language): language
        case .detectFromScript: detectedLanguageCode.flatMap { CueLanguage(identifier: $0) }
        }
    }

    /// The script's dominant language ("pt", "ja"), from its spoken words. Nil when unclear.
    static func detectedLanguageCode(in script: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(CueParser.stripCues(script))
        guard let language = recognizer.dominantLanguage else { return nil }
        return Locale.Language(identifier: language.rawValue).languageCode?.identifier
    }

    // MARK: - Helpers

    private static func regional(_ code: String, in preferredLanguages: [String]) -> [Locale] {
        preferredLanguages
            .map { Locale(identifier: $0) }
            .filter { $0.language.languageCode?.identifier == code }
    }

    private static func unique(_ locales: [Locale]) -> [Locale] {
        var seen = Set<String>()
        return locales.filter { seen.insert($0.identifier(.bcp47)).inserted }
    }
}
