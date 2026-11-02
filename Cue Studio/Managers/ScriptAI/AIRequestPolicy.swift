//
//  AIRequestPolicy.swift
//  Cue Studio
//

import Foundation

/// Route-specific payloads. Raw writing samples stay on the iPhone; PCC receives the creator's
/// preferences and measured style, rather than the imported or approved texts themselves.
nonisolated enum AIRequestPolicy {
    static let cloudVoiceBudget = 6_000
    static let cloudResponseTokens = 8_192
    static let cloudScriptAttempts = 2
    static let cloudLookupDeadline: Duration = .seconds(3)
    static func voice(_ original: CreatorVoice?, on route: AIModelRoute) -> CreatorVoice? {
        guard var voice = original, route == .privateCloud else { return original }
        voice.examples = []
        voice.excerpts = []
        voice.approvedSamples = []
        return voice
    }

    static func prepare(_ original: ScriptRequest, on route: AIModelRoute) -> ScriptRequest {
        var request = original
        request.modelRoute = route
        request.voice = voice(original.voice, on: route)
        // The usual length has already set the range on Auto (`ScriptRequestFactory.targetRange`); said in the brief as well it is a second
        // length beside a chosen one ("usually under 30 seconds" for a 3-minute video) or a target on Auto, where the duration is informative.
        request.voice?.reach.length = nil
        request.voiceBudget = route == .privateCloud ? cloudVoiceBudget : nil
        return request
    }
}
