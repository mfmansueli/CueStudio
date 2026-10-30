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
    /// The iPhone's own languages (never the interface's): their regional variants refine a language
    /// that was read from the idea, and settle a text that could be either of two languages.
    var preferredLanguages: [String] = []

    /// The platform an idea is for when the creator didn't choose one: their default, or TikTok.
    var defaultPlatform: Platform {
        let platform = profile.profile.defaultPlatform
        return Platform.primary.contains(platform) ? platform : .tiktok
    }

    /// - Parameter languageText: the creator's own words when `idea` wraps them in Cue's (an answered comment): the language is read
    ///   from them, not from the English around them.
    func request(
        idea: String, platform: Platform?, format: ScriptType?, length: ScriptLength = .auto, brand: BrandBrief? = nil, brief: IdeaBrief? = nil,
        languageText: String? = nil, formatChoice: FormatChoice? = nil
    ) -> ScriptRequest {
        let text = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        let platform = platform ?? defaultPlatform
        let format = formatChoice == nil ? format : formatChoice?.scriptType
        let effectiveLength = length == .auto ? (ScriptLength.detected(in: text) ?? .auto) : length
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        let isSerious = format?.structure.isSerious ?? false
        let language = writingLanguage(for: languageText ?? text)
        let voice = profile.writesInMyVoice && !isSerious
            ? profile.profile.voice(
                inLanguage: language?.locale.language.languageCode?.identifier, idea: text, professional: PlatformRegister(platform) == .professional
            ) : nil
        return ScriptRequest(
            source: .prompt(text),
            platform: platform,
            tone: nil,
            voice: voice,
            targetRange: targetRange(for: effectiveLength, platform: platform, preset: preset, voice: voice),
            durationPolicy: effectiveLength == .auto ? .informative : .targeted,
            language: language,
            languageVariant: writingVariant(for: languageText ?? text),
            format: format,
            // A brand brief only means something for a sponsored ad.
            brand: format == .ad ? brand : nil,
            // What the creator's text no longer says is not sent: their words win over the card's.
            brief: brief?.standing(in: text),
            formatChoice: formatChoice
        )
    }

    /// The least a spoken video can run and still say something (a hook, a point and a call to action, about 60 words at 150 a minute): what the creator's
    /// usual length may bring a script down to. The platforms' own ideals start higher (`PlatformRules.json`, revision 4).
    static let spokenFloor: TimeInterval = 25

    /// The most a script runs on Auto, whatever the creator's usual length (2 minutes, 300 words at 150 a minute): the owner's call, 29/10/2026.
    /// YouTube's long form, on a rig, keeps its own range.
    nonisolated static let autoCeiling: TimeInterval = 120

    /// How long the script runs: what the creator chose, or, on Auto, how long their videos usually are (they said so in My Cue Voice; a monetization
    /// goal left on by default shouldn't outweigh it, but nothing goes below the spoken floor or past `autoCeiling`), or else the platform's ideal.
    /// Long-form on a rig and Stories (a card of a few seconds, whatever their other videos are) keep the platform's own.
    func targetRange(for length: ScriptLength, platform: Platform, preset: PlatformPreset, voice: CreatorVoice?) -> ClosedRange<TimeInterval> {
        guard length == .auto, platform != .stories, !preset.prefersStudio, let usual = voice?.reach.length?.targetRange else {
            return length.targetRange(ideal: preset.idealRange)
        }
        let low = max(usual.lowerBound, Self.spokenFloor)
        return low...max(low, min(usual.upperBound, Self.autoCeiling))
    }

    /// The script language when one is set; otherwise the language the creator typed in; otherwise
    /// the interface's.
    func writingLanguage(for typed: String) -> CueLanguage? {
        knownLanguage(for: typed) ?? interfaceLanguage
    }

    /// The language the text would be drafted in when that is known before it is sent: the script language, or the one the text is
    /// written in. Nil while neither says (the interface's is only what a request falls back to, never a guess at the creator's).
    func knownLanguage(for typed: String) -> CueLanguage? {
        scriptLanguage ?? detectedLanguage(in: typed)
    }

    /// The creator's regional variant of the language, for a language Cue had to work out itself.
    /// Nil when the creator chose the language (their choice stands as picked) or has no variant.
    func writingVariant(for typed: String) -> Locale? {
        guard scriptLanguage == nil else { return nil }
        if let detected = detectedLanguage(in: typed) {
            return detected.variant(among: preferredLanguages, acceptingAnyVariant: true)
        }
        return interfaceLanguage?.variant(among: preferredLanguages)
    }

    /// What the idea is written in, when it says enough (three words, or a script without spaces).
    /// Read the same way dictation hears it (`LanguageService.dictationRequest`), so what the creator
    /// says and what is written agree.
    private func detectedLanguage(in typed: String) -> CueLanguage? {
        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.split(whereSeparator: \.isWhitespace).count >= 3 || WordSegmenter.containsUnspacedScript(typed) else { return nil }
        return LanguageDetector.language(in: typed, preferring: preferredLanguages)
    }
}
