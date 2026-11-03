//
//  UltraPrice.swift
//  Cue Studio
//

import Foundation

/// What Google charges for Ultra's model (`FirebaseUltraClient.modelName` at the `global` location), in US dollars per million tokens, from the
/// Cloud Billing catalog of Vertex AI (read 31/10/2026): "Gemini 3.5 Flash Global Text Input - Predictions" 1.50, "… Global Text Input Caching"
/// 0.15 and "… Global Text Output - Predictions" 9.00. Thinking is billed as output. `tools/ultra/spend.js` reads the catalog again on every run
/// and says when these no longer match it.
nonisolated struct UltraPrice: Hashable, Sendable {
    var inputPerMillion: Double
    /// The part of the prompt Google served from its cache.
    var cachedInputPerMillion: Double
    /// The answer and the thinking before it.
    var outputPerMillion: Double

    static let google = UltraPrice(inputPerMillion: 1.50, cachedInputPerMillion: 0.15, outputPerMillion: 9.00)

    /// The price of the model that writes now: in a Debug build, the lab's pick (`UltraLabProvider`, Gemini or Claude).
    static var current: UltraPrice {
        #if DEBUG
        UltraLabProvider.selected.price
        #else
        google
        #endif
    }
}
