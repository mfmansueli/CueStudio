//
//  UltraModelReply.swift
//  Cue Studio
//

import Foundation

/// What one Gemini call answered, without anything of the request: the text, whether the model stopped by itself (not at the token cap, a safety
/// block or a dropped stream), and what it cost in tokens, for the lab's records. Never logged with its text.
nonisolated struct UltraModelReply: Hashable, Sendable {
    var text: String
    /// The model ended its answer normally (`FinishReason.stop`).
    var finishedNormally: Bool
    /// The whole prompt, as Google counted it (`UltraCost` prices these).
    var promptTokens: Int?
    /// The part of the prompt served from Google's cache.
    var cachedTokens: Int?
    var outputTokens: Int?
    var thinkingTokens: Int?
    /// The model version the provider reports, which can differ from the one asked for.
    var modelVersion: String?
}
