//
//  InterfaceLocale.swift
//  Cue Studio
//

import Foundation
import Synchronization

/// The locale of Cue's interface language (Profile › Language & Region), for strings resolved
/// outside SwiftUI views (`String(localized:)` everywhere, from any thread). SwiftUI views read it
/// from the environment instead. Set by `LanguageService` through `AppServices`; nil until then,
/// which resolves strings the way Foundation does on its own (unit tests, previews).
nonisolated enum InterfaceLocale {
    private static let storage = Mutex<Locale?>(nil)

    static var current: Locale? {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}

extension Locale {
    /// Numbers, dates and times in the interface language, with the iPhone's region ("en" in Italy
    /// formats as English in Italy). Use for any `formatted(…)` shown in the interface.
    nonisolated static var interface: Locale {
        guard let language = InterfaceLocale.current?.language else { return .current }
        var components = Locale.Components(languageCode: language.languageCode, script: language.script, languageRegion: language.region)
        components.region = Locale.current.region
        return Locale(components: components)
    }
}
