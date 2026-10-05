//
//  SpeechLocaleCatalog.swift
//  Cue Studio
//

import Foundation

/// What each recognizer supports on this device. Tests answer with a fixed list.
protocol SpeechLocaleCatalog: Sendable {
    func isAvailable(_ engine: SpeechEngine) async -> Bool
    /// The recognizer's own locale for `locale` ("pt" may answer "pt-PT"), or nil.
    func supportedLocale(equivalentTo locale: Locale, engine: SpeechEngine) async -> Locale?
    /// Whether the model `route` needs is installed and can run. Never downloads it.
    func assetStatus(of route: SpeechRoute) async -> SpeechAssetStatus
}
