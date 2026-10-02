//
//  SpeechLocaleResolver.swift
//  Cue Studio
//

import Foundation

/// Turns the language Voice Following should listen for into a recognizer and a locale this device
/// supports.
///
/// - A chosen language is recognized in that language and variant only (pt-BR, never pt-PT). When
///   the device can't, the answer is "unavailable", never another language.
/// - A detected language (a script on Auto-detect) works as Voice Following always has: the
///   creator's own regional variant first (en-GB over en-US), then Cue's default for the language.
/// - `SpeechTranscriber` is tried before `DictationTranscriber` for every candidate, so a language
///   it supports is recognized exactly as before. Hindi is the exception: `SpeechTranscriber` writes
///   it in Latin letters, so a script in Devanagari is heard by `DictationTranscriber` first (which
///   writes Devanagari), and one written in Latin letters by `SpeechTranscriber` first.
nonisolated struct SpeechLocaleResolver: Sendable {
    let catalog: SpeechLocaleCatalog

    init(catalog: SpeechLocaleCatalog = AppleSpeechLocaleCatalog()) {
        self.catalog = catalog
    }

    /// - Parameter scriptText: what will be read, so the recognizer writes in the same letters.
    func resolve(_ request: SpeechLanguageRequest, scriptText: String = "") async -> Result<SpeechRoute, SpeechUnavailableReason> {
        guard let target = Self.target(for: request) else { return .failure(.unknownLanguage) }
        var anyEngine = false
        let text: String = if case .detect(let detected, _) = request { detected } else { scriptText }
        for engine in Self.engines(for: target.language, scriptText: text) {
            guard await catalog.isAvailable(engine) else { continue }
            anyEngine = true
            for candidate in target.candidates {
                guard let supported = await catalog.supportedLocale(equivalentTo: candidate, engine: engine),
                      target.accepts(supported) else { continue }
                return .success(SpeechRoute(engine: engine, locale: supported, language: target.language))
            }
        }
        guard anyEngine else { return .failure(.noRecognition) }
        if let language = target.language, !target.isDetected {
            return .failure(.unsupported(language))
        }
        return .failure(.unsupportedDetected(target.name))
    }

    // MARK: - Engines

    /// The order the recognizers are tried in.
    static func engines(for language: CueLanguage?, scriptText: String) -> [SpeechEngine] {
        guard language == .hindi, scriptText.unicodeScalars.contains(where: { (0x0900...0x097F).contains($0.value) }) else {
            return [.transcriber, .dictation]
        }
        return [.dictation, .transcriber]
    }

    // MARK: - Candidates

    /// What to ask the recognizers for, in order, and which of their answers count.
    struct Target: Equatable {
        let candidates: [Locale]
        let language: CueLanguage?
        let languageCode: String
        let isDetected: Bool

        func accepts(_ locale: Locale) -> Bool {
            if let language, !isDetected { return language.accepts(locale) }
            return locale.language.languageCode?.identifier == languageCode
        }

        var name: String {
            language?.localizedName
                ?? (InterfaceLocale.current ?? .current).localizedString(forLanguageCode: languageCode)
                ?? languageCode
        }
    }

    static func target(for request: SpeechLanguageRequest) -> Target? {
        switch request {
        case .language(let language):
            return Target(candidates: [language.speechLocale], language: language, languageCode: language.languageCode, isDetected: false)
        case .detect(let text, let systemLanguages):
            let detected = LanguageDetector.dominantLanguageCode(in: text, preferring: systemLanguages)
                ?? (text.isEmpty ? systemLanguages.first.flatMap { Locale.Language(identifier: $0).languageCode?.identifier } : nil)
            guard let code = detected else { return nil }
            let language = CueLanguage.matching(languageCode: code)
            var candidates = systemLanguages
                .map { Locale(identifier: $0) }
                .filter { $0.language.languageCode?.identifier == code }
            if let language { candidates.append(language.speechLocale) }
            candidates.append(Locale(identifier: code))
            var seen = Set<String>()
            candidates = candidates.filter { seen.insert($0.identifier(.bcp47)).inserted }
            return Target(candidates: candidates, language: language, languageCode: code, isDetected: true)
        }
    }
}
