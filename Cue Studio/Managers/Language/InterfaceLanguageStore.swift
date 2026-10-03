//
//  InterfaceLanguageStore.swift
//  Cue Studio
//

import Foundation
import UIKit

/// The real interface switch, with two halves:
/// - the system's per-app language (`AppleLanguages` in Cue's own defaults, the list Settings ›
///   Cue › Language edits), so every launch after the change starts natively in the language:
///   strings, formats, right-to-left layout, system alerts and permission prompts;
/// - `LocalizedBundle`, so the running app switches immediately instead of on the next launch.
///
/// It never touches the iPhone's own language or any other app.
struct InterfaceLanguageStore: InterfaceLanguageApplying {
    /// False keeps the choice out of the system list (UI tests start every launch clean).
    var persists = true
    private let defaults = UserDefaults.standard

    var systemAppLanguage: String? {
        guard persists, let domain = Bundle.main.bundleIdentifier else { return nil }
        let languages = defaults.persistentDomain(forName: domain)?[DefaultsKey.appleLanguages] as? [String]
        return languages?.first
    }

    func apply(_ localization: String?) -> String? {
        if persists {
            if let localization {
                defaults.set([localization], forKey: DefaultsKey.appleLanguages)
            } else {
                defaults.removeObject(forKey: DefaultsKey.appleLanguages)
            }
        }
        // Back to the iPhone's language before anything was switched: nothing to do, the app
        // already runs in it.
        guard localization != nil || LocalizedBundle.isActive else { return nil }
        let shown = localization ?? systemLocalization
        LocalizedBundle.activate(shown)
        // UIKit views made from now on (navigation bars, sheets, the tab bar) lay out in the
        // language's direction; SwiftUI content follows the environment `RootView` sets.
        let rightToLeft = Locale.Language(identifier: shown).characterDirection == .rightToLeft
        UIView.appearance().semanticContentAttribute = rightToLeft ? .forceRightToLeft : .forceLeftToRight
        return shown
    }

    /// The localization the iPhone's own language list picks among the ones Cue ships. Read after
    /// Cue's entry is removed, so it falls through to the system's list.
    private var systemLocalization: String {
        let preferences = defaults.stringArray(forKey: DefaultsKey.appleLanguages) ?? Locale.preferredLanguages
        let shipped = Bundle.main.localizations.filter { $0 != "Base" }
        return Bundle.preferredLocalizations(from: shipped, forPreferences: preferences).first ?? "en"
    }
}
