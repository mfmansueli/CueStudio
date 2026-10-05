//
//  AppleLanguageCapabilityChecker.swift
//  Cue Studio
//

import Foundation
import Translation

/// The device's own answers: the app's localizations for the interface, FoundationModels for Apple
/// Intelligence, the Speech framework for dictation, Voice Following and captions, and Translation for
/// translating captions. None implies another: a language Apple Intelligence doesn't write can still
/// have a speech model, and the other way around.
nonisolated struct AppleLanguageCapabilityChecker: LanguageCapabilityChecking {
    let ai: AIModelCapabilities
    let speech: SpeechCapabilityChecker
    let translations: TranslationAvailabilityChecking
    let localizations: [String]

    init(
        ai: AIModelCapabilities = AppleAIModelCapabilities(usesPrivateCloudCompute: ScriptAIService.hasPrivateCloudComputeEntitlement),
        speech: SpeechCapabilityChecker = SpeechCapabilityChecker(),
        translations: TranslationAvailabilityChecking = AppleTranslationAvailability(),
        localizations: [String] = Bundle.main.localizations
    ) {
        self.ai = ai
        self.speech = speech
        self.translations = translations
        self.localizations = localizations
    }

    func support(_ feature: LanguageFeature, for language: CueLanguage) async -> FeatureSupport {
        switch feature {
        case .interface: interface(language)
        case .aiWriting: await aiWriting(language)
        case .dictation, .voiceFollowing, .captions: await speech.support(for: language)
        }
    }

    func translation(from source: Locale.Language, to target: Locale.Language) async -> FeatureSupport {
        switch await translations.support(from: source, to: target) {
        case .installed: .supported
        case .downloadable: .notInstalled
        case .unsupported: .unavailable(.languageNotSupported)
        }
    }

    // MARK: - Features

    /// Cue's interface has a translation for the language as Cue writes it. Another variant of it
    /// (pt-PT) reads in the language it falls back to and is never claimed as translated.
    private func interface(_ language: CueLanguage) -> FeatureSupport {
        localizations.contains { $0.caseInsensitiveCompare(language.interfaceLocalization) == .orderedSame }
            ? .supported : .unavailable(.variantNotTranslated)
    }

    private func aiWriting(_ language: CueLanguage) async -> FeatureSupport {
        let locale = language.locale
        switch ai.deviceStatus {
        case .deviceNotEligible:
            if await cloudWrites(locale) { return .supported }
            return .unavailable(.deviceNotSupported)
        case .turnedOff:
            return .unavailable(.turnedOff)
        case .available, .preparing, .quotaReached:
            guard ai.deviceSupports(locale) else {
                return await cloudWrites(locale) ? .supported : .unavailable(.languageNotSupported)
            }
            return ai.deviceStatus == .preparing ? .notInstalled : .supported
        }
    }

    /// Private Cloud Compute, only where the app offers it.
    private func cloudWrites(_ locale: Locale) async -> Bool {
        guard ai.cloudStatus == .available else { return false }
        return await ai.cloudSupports(locale)
    }
}
