//
//  LanguageSettingsService.swift
//  Cue Studio
//

import SwiftUI

/// Profile › Settings › Language & Region: three independent choices, kept between launches.
/// - `appLanguage`: Cue's interface. Changes nothing else: no script is translated, Voice Following
///   keeps listening for its own language, the iPhone keeps its language.
/// - `voiceFollowingLanguage`: what Voice Following listens for.
/// - `scriptLanguage`: the language new scripts start in (each script keeps its own afterwards).
///
/// Setting one never writes another; each has its own key.
@MainActor
@Observable
final class LanguageSettingsService {
    /// Nil follows the iPhone's language.
    var appLanguage: CueLanguage? {
        didSet {
            guard appLanguage != oldValue else { return }
            store(appLanguage?.rawValue, key: DefaultsKey.appLanguage)
            interfaceLocalization = applier.apply(appLanguage?.localizationIdentifier)
        }
    }

    var voiceFollowingLanguage: VoiceFollowingLanguage {
        didSet { defaults.set(voiceFollowingLanguage.storageValue, forKey: DefaultsKey.voiceFollowingLanguage) }
    }

    /// Nil is Auto-detect.
    var scriptLanguage: CueLanguage? {
        didSet { store(scriptLanguage?.rawValue, key: DefaultsKey.scriptLanguage) }
    }

    /// The localization the running interface was switched to, or nil when it runs in the language
    /// the system started it in (see `InterfaceLanguageApplying`).
    private(set) var interfaceLocalization: String? = nil

    private let defaults: UserDefaults
    private let applier: InterfaceLanguageApplying

    init(defaults: UserDefaults = .standard, applier: InterfaceLanguageApplying = InterfaceLanguageStore()) {
        self.defaults = defaults
        self.applier = applier
        voiceFollowingLanguage = VoiceFollowingLanguage(storageValue: defaults.string(forKey: DefaultsKey.voiceFollowingLanguage))
        scriptLanguage = defaults.string(forKey: DefaultsKey.scriptLanguage).flatMap(CueLanguage.init(rawValue:))
        var language = defaults.string(forKey: DefaultsKey.appLanguage).flatMap(CueLanguage.init(rawValue:))
        // Settings › Cue › Language rewrites the system's list; when it disagrees with Cue's own
        // choice, the creator changed it there last, so Cue follows.
        var changedInSettings = false
        if let system = applier.systemAppLanguage, system != language?.localizationIdentifier {
            language = CueLanguage(identifier: system)
            changedInSettings = true
        }
        appLanguage = language
        if changedInSettings {
            store(language?.rawValue, key: DefaultsKey.appLanguage)
        }
        if let language {
            interfaceLocalization = applier.apply(language.localizationIdentifier)
        }
    }

    // MARK: - Interface

    /// The locale SwiftUI resolves strings and formats with; nil leaves the system's.
    var interfaceLocale: Locale? {
        interfaceLocalization.map { Locale(identifier: $0) }
    }

    /// Right to left for Arabic; nil leaves the system's direction.
    var layoutDirection: LayoutDirection? {
        interfaceLocalization.map {
            Locale.Language(identifier: $0).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
        }
    }

    /// "English", or the iPhone's language when Cue follows it.
    var appLanguageLabel: String {
        appLanguage?.nativeName ?? String(localized: "iPhone Language")
    }

    var scriptLanguageLabel: String {
        scriptLanguage?.nativeName ?? String(localized: "Auto-detect")
    }

    // MARK: - Storage

    private func store(_ value: String?, key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
