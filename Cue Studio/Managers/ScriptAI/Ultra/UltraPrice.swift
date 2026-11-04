//
//  UltraPrice.swift
//  Cue Studio
//

import Foundation

/// What Ultra's model charges, in US dollars per million tokens; thinking is billed as output. Claude's from Anthropic's pricing page. Google's,
/// for the lab's Gemini (`FirebaseUltraClient.modelName` at the `global` location), from the Cloud Billing catalog of Vertex AI (read
/// 31/10/2026): "Gemini 3.5 Flash Global Text Input - Predictions" 1.50, "… Global Text Input Caching" 0.15 and "… Global Text Output -
/// Predictions" 9.00; `tools/ultra/spend.js` reads the catalog again on every run and says when these no longer match it.
nonisolated struct UltraPrice: Hashable, Sendable {
    var inputPerMillion: Double
    /// The part of the prompt Google served from its cache.
    var cachedInputPerMillion: Double
    /// The answer and the thinking before it.
    var outputPerMillion: Double

    static let google = UltraPrice(inputPerMillion: 1.50, cachedInputPerMillion: 0.15, outputPerMillion: 9.00)

    /// Claude's price for a model id (Anthropic's pricing page, read 02/11/2026); Sonnet's for an id it doesn't know. Haiku's is for prompts up
    /// to 100K tokens, which a script's always are.
    static func claude(_ model: String?) -> UltraPrice {
        switch model {
        case "claude-opus-5-5": UltraPrice(inputPerMillion: 4, cachedInputPerMillion: 0.20, outputPerMillion: 20)
        case "claude-haiku-5-5": UltraPrice(inputPerMillion: 0.10, cachedInputPerMillion: 0.01, outputPerMillion: 0.50)
        default: UltraPrice(inputPerMillion: 2, cachedInputPerMillion: 0.20, outputPerMillion: 10)
        }
    }

    /// The price of the model Cue's server last answered with (`CueServerUltraClient.lastModelKey`): the server picks the model, so the app
    /// learns it from the answers.
    static var server: UltraPrice {
        claude(UserDefaults.standard.string(forKey: CueServerUltraClient.lastModelKey))
    }

    /// The price of the model that writes now: Cue's server's, or in a Debug build the lab's pick (`UltraLabProvider`).
    static var current: UltraPrice {
        #if DEBUG
        UltraLabProvider.selected.price
        #else
        server
        #endif
    }
}
