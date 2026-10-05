//
//  SpeechCapabilityChecker.swift
//  Cue Studio
//

import Foundation

/// Whether this device can recognize a language's speech: which recognizer would be used
/// (`SpeechLocaleResolver`), and whether its model is on the device. The one answer Voice Following,
/// dictation and captions share, since all three listen through the same recognizers. Never downloads.
nonisolated struct SpeechCapabilityChecker: Sendable {
    let resolver: SpeechLocaleResolver
    let catalog: SpeechLocaleCatalog

    init(catalog: SpeechLocaleCatalog = AppleSpeechLocaleCatalog()) {
        self.catalog = catalog
        resolver = SpeechLocaleResolver(catalog: catalog)
    }

    func support(for language: CueLanguage) async -> FeatureSupport {
        // Hindi is written in Devanagari, which only the dictation model writes: ask for the one a script in it would use.
        switch await resolver.resolve(.language(language), scriptText: language.nativeName) {
        case .failure(.noRecognition):
            return .unavailable(.deviceNotSupported)
        case .failure:
            return .unavailable(.languageNotSupported)
        case .success(let route):
            switch await catalog.assetStatus(of: route) {
            case .ready: return .supported
            case .needsDownload: return .notInstalled
            case .unsupported: return .unavailable(.languageNotSupported)
            case .cannotRun: return .unavailable(.deviceNotSupported)
            }
        }
    }
}
