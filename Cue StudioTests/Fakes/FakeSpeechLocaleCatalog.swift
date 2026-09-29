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

    func isAvailable(_ engine: SpeechEngine) async -> Bool {
        !(engine == .transcriber ? transcriber : dictation).isEmpty
    }

    func supportedLocale(equivalentTo locale: Locale, engine: SpeechEngine) async -> Locale? {
        let supported = engine == .transcriber ? transcriber : dictation
        let identifier = locale.identifier(.bcp47)
        if supported.contains(identifier) { return Locale(identifier: identifier) }
        if let fallback = defaults[identifier], supported.contains(fallback) { return Locale(identifier: fallback) }
        return nil
    }
}
