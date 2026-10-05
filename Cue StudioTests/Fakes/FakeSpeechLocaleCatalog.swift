//
//  FakeSpeechLocaleCatalog.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A device's speech support as a fixed list: which locales each recognizer knows, and how it
/// answers a locale without a region (the dictation model answers "pt" with pt-PT).
nonisolated struct FakeSpeechLocaleCatalog: SpeechLocaleCatalog {
    var transcriber: [String] = []
    var dictation: [String] = []
    /// Region-less answers: "pt" → "pt-PT".
    var defaults: [String: String] = [:]
    /// Locales (BCP 47) whose model is on the device; every other supported one downloads on first use.
    var installed: Set<String> = []
    /// Locales whose model is listed and installed but can't take audio (the simulator).
    var cannotRun: Set<String> = []

    func isAvailable(_ engine: SpeechEngine) async -> Bool {
        !(engine == .transcriber ? transcriber : dictation).isEmpty
    }

    func supportedLocale(equivalentTo locale: Locale, engine: SpeechEngine) async -> Locale? {
        let supported = engine == .transcriber ? transcriber : dictation
        let identifier = locale.identifier(.bcp47)
        if supported.contains(identifier) { return Locale(identifier: identifier) }
        // The framework answers "zh-Hant-HK" with its own "zh-HK": same language and region, script aside.
        if let code = locale.language.languageCode?.identifier, let region = locale.region?.identifier,
           supported.contains("\(code)-\(region)") {
            return Locale(identifier: "\(code)-\(region)")
        }
        if let fallback = defaults[identifier], supported.contains(fallback) { return Locale(identifier: fallback) }
        return nil
    }

    func assetStatus(of route: SpeechRoute) async -> SpeechAssetStatus {
        let identifier = route.locale.identifier(.bcp47)
        let supported = route.engine == .transcriber ? transcriber : dictation
        guard supported.contains(identifier) else { return .unsupported }
        if cannotRun.contains(identifier) { return .cannotRun }
        return installed.contains(identifier) ? .ready : .needsDownload
    }
}
