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
    let profile: CreatorProfileService
    /// Language & Region's script language; nil is Auto-detect.
    let scriptLanguage: CueLanguage?
    /// What the interface is in: an idea with nothing else to go by is written in it.
    let interfaceLanguage: CueLanguage?
    /// The iPhone's own languages (never the interface's): their regional variants refine a language
    /// that was read from the idea, and settle a text that could be either of two languages.
    var preferredLanguages: [String] = []

    /// The platform an idea is for when the creator didn't choose one in the dock's Create for: their default (Profile), whichever it is,
    /// the same one a blank script gets.
    var defaultPlatform: Platform { profile.profile.defaultPlatform }

    /// - Parameter languageText: the creator's own words when `idea` wraps them in Cue's (an answered comment): the language is read
    ///   from them, not from the English around them.
    /// - Parameter engine: who writes it. On Auto, Ultra writes to all of 1:15 to 2:30 and Apple Intelligence to the part of it where it
    ///   writes best (`targetRange`).
    func request(
        idea: String, platform: Platform?, format: ScriptType?, length: ScriptLength = .auto, brand: BrandBrief? = nil, brief: IdeaBrief? = nil,
        languageText: String? = nil, formatChoice: FormatChoice? = nil, engine: ScriptEngine = .apple
    ) -> ScriptRequest {
        let text = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        let platform = platform ?? defaultPlatform
        let format = formatChoice == nil ? format : formatChoice?.scriptType
        let effectiveLength = length == .auto ? (ScriptLength.detected(in: text) ?? .auto) : length
        let isSerious = format?.structure.isSerious ?? false
        let language = writingLanguage(for: languageText ?? text)
        var theirs = profile.writesInMyVoice
            ? profile.profile.voice(
                inLanguage: language?.locale.language.languageCode?.identifier, idea: text, professional: PlatformRegister(platform) == .professional
            ) : nil
        // At most three catchphrases, taking turns (the owner's B10; §11, A9): the starter moves the turn on once the script is sent.
        theirs?.phrases = profile.nextCatchphrases
        let voice = isSerious ? nil : theirs
        var request = ScriptRequest(
            source: .prompt(text),
            platform: platform,
            voice: voice,
            targetRange: targetRange(for: effectiveLength, voice: voice, engine: engine),
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
        if isSerious { request.rules = theirs?.restrictionsOnly }
        request.engine = engine
        return request
    }

    /// The least a spoken video can run and still say something (a hook, a point and a call to action, about 60 words at 150 a minute): what the creator's
    /// usual length may bring a script down to. Scripts on Auto start higher (`writingRange`).
    static let spokenFloor: TimeInterval = 25

    /// The most a script runs on Auto, whatever the creator's usual length: the top of `writingRange` (2:30, 375 words at 150 a minute; the
    /// owner's call of 04/11/2026, after two minutes since 29/10). Apple Intelligence stops where it writes well (`AppleScriptLength.ceiling`).
    nonisolated static let autoCeiling: TimeInterval = 150

    /// What a script is written to on Auto on every network, YouTube's long form included: 1:15 to 2:30, the owner's call of 04/11/2026 ("o
    /// roteiro é sempre um rascunho inicial, ela precisa lapidar": growing it into a long YouTube video is the creator's). Ultra writes to all of
    /// it, Apple Intelligence to the part where it writes best (`AppleScriptLength.window`). It is the writers' own: the screen shows every
    /// creator the network's goal (`PlatformRules.json`: the same 1:15 to 2:30 but YouTube's, 4 to 10 minutes, 8 to 15 with a monetization goal),
    /// whoever writes ("o tempo do front-end deve refletir para todos, mas o que o back-end faz no tempo fica no back-end").
    nonisolated static let writingRange: ClosedRange<TimeInterval> = 75...autoCeiling

    /// How long the script runs: what the creator chose, or, on Auto, how long their videos usually are (they said so in My Cue Voice; nothing
    /// goes below the spoken floor or past the ceiling: `autoCeiling` for Ultra, `AppleScriptLength.ceiling` for Apple Intelligence), or else
    /// `writingRange`: all of it for Ultra, the part Apple Intelligence writes best (`AppleScriptLength.window`). The same on every network.
    func targetRange(for length: ScriptLength, voice: CreatorVoice?, engine: ScriptEngine = .apple) -> ClosedRange<TimeInterval> {
        guard length == .auto else { return length.targetRange(ideal: Self.writingRange) }
        let ceiling = engine == .ultra ? Self.autoCeiling : AppleScriptLength.ceiling
        guard let usual = voice?.reach.length?.targetRange else {
            return engine == .ultra ? Self.writingRange : AppleScriptLength.window(within: Self.writingRange)
        }
        let low = max(usual.lowerBound, Self.spokenFloor)
        return low...max(low, min(usual.upperBound, ceiling))
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
