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
    var promptTokens: Int?
    var outputTokens: Int?
    var thinkingTokens: Int?
    /// The model version the provider reports, which can differ from the one asked for.
    var modelVersion: String?
}
