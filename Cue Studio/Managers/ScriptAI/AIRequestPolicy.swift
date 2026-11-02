//
//  AIRequestPolicy.swift
//  Cue Studio
//

import Foundation

/// Route-specific payloads. The voice goes whole to both Apple Intelligence routes: Private Cloud Compute gets the proof (pasted examples,
/// imported excerpts, approved scripts) the way the device does (the owner's D1, 02/11/2026), bounded the same way (`VoiceExample.limit` of them,
/// `VoiceExample.sentCharacters` each, inside `cloudVoiceBudget`). Ultra AI never gets the proof (`VoiceBriefBuilder.ultraProjection`).
nonisolated enum AIRequestPolicy {
    static let cloudVoiceBudget = 6_000
    static let cloudResponseTokens = 8_192
    static let cloudScriptAttempts = 2
    static let cloudLookupDeadline: Duration = .seconds(3)

    static func prepare(_ original: ScriptRequest, on route: AIModelRoute) -> ScriptRequest {
        var request = original
        request.modelRoute = route
        // The usual length has already set the range on Auto (`ScriptRequestFactory.targetRange`); said in the brief as well it is a second
        // length beside a chosen one ("usually under 30 seconds" for a 3-minute video) or a target on Auto, where the duration is informative.
        request.voice?.reach.length = nil
        request.voiceBudget = route == .privateCloud ? cloudVoiceBudget : nil
        return request
    }
}
