//
//  ScriptRequestFactory.swift
//  Cue Studio
//

import Foundation

/// Turns the idea on the card (and the choices around it: platform, format, "My Cue Voice") into
/// the request Apple Intelligence writes from. One place decides the length, the voice and the
/// language, so the card, the ideas sheet and a retry all ask the same way.
@MainActor
struct ScriptRequestFactory {
    let rules: PlatformRulesService
    let profile: CreatorProfileService
    /// Language & Region's script language; nil is Auto-detect.
    let scriptLanguage: CueLanguage?
    /// What the interface is in: an idea with nothing else to go by is written in it.
    let interfaceLanguage: CueLanguage?

    /// The platform an idea is for when the creator didn't choose one: their default, or TikTok.
    var defaultPlatform: Platform {
        let platform = profile.profile.defaultPlatform
        return Platform.primary.contains(platform) ? platform : .tiktok
    }

    func request(
        idea: String, platform: Platform?, format: ScriptType?, length: ScriptLength = .auto, brand: BrandBrief? = nil
    ) -> ScriptRequest {
        let text = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        let platform = platform ?? defaultPlatform
        let effectiveLength = length == .auto ? (ScriptLength.detected(in: text) ?? .auto) : length
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        let isSerious = format?.structure.isSerious ?? false
        return ScriptRequest(
            source: .prompt(text),
            platform: platform,
            tone: nil,
            voice: profile.writesInMyVoice && !isSerious ? profile.profile.voice : nil,
            targetRange: effectiveLength.targetRange(ideal: preset.idealRange),
            language: writingLanguage(for: text),
            format: format,
            // A brand brief only means something for a sponsored ad.
            brand: format == .ad ? brand : nil
        )
    }

    /// The script language when one is set; otherwise the language the creator typed in; otherwise
    /// the interface's.
    func writingLanguage(for typed: String) -> CueLanguage? {
        if let scriptLanguage { return scriptLanguage }
        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if typed.split(whereSeparator: \.isWhitespace).count >= 3 || WordSegmenter.containsUnspacedScript(typed),
           let detected = LanguageDetector.language(in: typed) {
            return detected
        }
        return interfaceLanguage
    }
}
