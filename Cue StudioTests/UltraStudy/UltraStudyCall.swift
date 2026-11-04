//
//  UltraStudyCall.swift
//  Cue StudioTests
//

import Foundation

/// One call the study's client made (`UltraStudyClient`), kept whole for the report: what went out, what came back, Claude's token counts
/// (the cost is priced from them by `tools/ultra/study/cost.py`), how long it took and how many tries it needed.
nonisolated struct UltraStudyCall: Codable, Sendable {
    let stage: String
    let model: String
    let effort: String
    let instructions: String
    let prompt: String
    var text = ""
    var finishedNormally = false
    /// The model Claude reports (a refusal re-run by the fallback names another).
    var modelVersion: String?
    var inputTokens: Int?
    var cacheReadTokens: Int?
    var outputTokens: Int?
    var seconds = 0.0
    /// Tries, the first included: a rate limit or an overloaded API is waited out and tried again (the server's SDK retries once).
    var attempts = 0
    /// "ok", "skipped" (a fit the study's length rule doesn't need) or the failure's kind.
    var outcome = "ok"
}
