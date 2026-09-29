//
//  AppleSpeechLocaleCatalog.swift
//  Cue Studio
//

import Foundation
import Speech

/// Asks the Speech framework. The answer depends on the device (and the simulator has no
/// `SpeechTranscriber`), so it is never assumed.
nonisolated struct AppleSpeechLocaleCatalog: SpeechLocaleCatalog {
    func isAvailable(_ engine: SpeechEngine) async -> Bool {
        switch engine {
        case .transcriber: SpeechTranscriber.isAvailable
        case .dictation: !(await DictationTranscriber.supportedLocales).isEmpty
        }
    }

    func supportedLocale(equivalentTo locale: Locale, engine: SpeechEngine) async -> Locale? {
        switch engine {
        case .transcriber: await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        case .dictation: await DictationTranscriber.supportedLocale(equivalentTo: locale)
        }
    }
}
