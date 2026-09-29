//
//  SystemAppLanguageStore.swift
//  Cue Studio
//

import Foundation

/// Keeps the interface language in the app's `AppleLanguages`, the list Settings › Cue › Language
/// edits too. The system reads it at launch, so every later launch is natively in that language:
/// permission prompts, system sheets, formats and right to left included. `LanguageService` switches
/// the running interface on its own.
///
/// The list is written as the chosen language followed by the iPhone's languages. While it is set
/// the iPhone's list can't be read any other way, and Voice Following needs it.
final class SystemAppLanguageStore: AppLanguageStoring {
    private static let key = "AppleLanguages"

    private let defaults: UserDefaults
    private let bundle: Bundle

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
    }

    /// Only the app's own domain: the global list is the iPhone's.
    private var override: [String]? {
        guard let domain = bundle.bundleIdentifier else { return nil }
        return defaults.persistentDomain(forName: domain)?[Self.key] as? [String]
    }

    var chosenLocalization: String? {
        get {
            guard let first = override?.first else { return nil }
            return Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [first]).first
        }
        set {
            let system = systemLanguages
            if let newValue {
                defaults.set([newValue] + system.filter { $0 != newValue }, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }

    var systemLocalization: String {
        Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: systemLanguages).first
            ?? bundle.developmentLocalization ?? "en"
    }

    var systemLanguages: [String] {
        if let override { return Array(override.dropFirst()) }
        return Locale.preferredLanguages
    }
}
