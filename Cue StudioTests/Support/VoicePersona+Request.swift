//
//  VoicePersona+Request.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
extension VoicePersona {
    /// The request the card sends for `idea`, built by the factory the app uses (language read from the idea, TikTok, no format).
    /// - Parameter withVoice: "Write in my voice" on or off.
    /// - Parameter profile: the profile to use in place of the persona's own (the same creator with more answered).
    func request(for idea: String, withVoice: Bool = true, profile override: CreatorProfile? = nil) -> ScriptRequest {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        var held = override ?? profile
        held.usesVoiceInAI = withVoice
        service.profile = held
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: .english,
            preferredLanguages: ["en-US"]
        )
        return factory.request(idea: idea, platform: .tiktok, format: nil)
    }
}
