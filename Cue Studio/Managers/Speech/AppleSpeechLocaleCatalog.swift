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

    func assetStatus(of route: SpeechRoute) async -> SpeechAssetStatus {
        let modules: [any SpeechModule] = switch route.engine {
        case .transcriber:
            [SpeechTranscriber(locale: route.locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])]
        case .dictation:
            [DictationTranscriber(locale: route.locale, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [])]
        }
        switch await AssetInventory.status(forModules: modules) {
        case .installed:
            // Some devices list a model they can't run (the simulator): no audio format for it.
            return await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) == nil ? .cannotRun : .ready
        case .unsupported:
            return .unsupported
        default:
            return .needsDownload
        }
    }
}
