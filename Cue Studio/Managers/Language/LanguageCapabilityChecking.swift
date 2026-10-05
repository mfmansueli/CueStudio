//
//  LanguageCapabilityChecking.swift
//  Cue Studio
//

import Foundation

/// Asks the system what this device can do with a language, one feature at a time. Real answers come
/// from Apple's frameworks (`AppleLanguageCapabilityChecker`); tests give a fixed list. Never downloads anything.
nonisolated protocol LanguageCapabilityChecking: Sendable {
    func support(_ feature: LanguageFeature, for language: CueLanguage) async -> FeatureSupport
    /// Whether the Translation framework can translate `source` into `target` here.
    func translation(from source: Locale.Language, to target: Locale.Language) async -> FeatureSupport
}
