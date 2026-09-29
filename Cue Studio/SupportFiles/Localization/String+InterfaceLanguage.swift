//
//  String+InterfaceLanguage.swift
//  Cue Studio
//

import Foundation

extension String {
    /// `String(localized:)` in the interface language picked in Cue, which can differ from the
    /// iPhone's and changes without a relaunch.
    ///
    /// This overload is more specific than Foundation's `String(localized:table:bundle:locale:comment:)`,
    /// so every `String(localized: "…")` in the app resolves here. Foundation's picks the language
    /// once per launch and doesn't go through `Bundle` overrides; a `LocalizedStringResource` with a
    /// locale is looked up in that locale's `.lproj` (and falls back to English, the development
    /// language, for anything untranslated). Xcode still extracts these strings into the catalog.
    nonisolated init(localized keyAndValue: String.LocalizationValue, comment: StaticString? = nil) {
        var resource = LocalizedStringResource(keyAndValue, comment: comment)
        if let locale = InterfaceLocale.current {
            resource.locale = locale
        }
        self.init(localized: resource)
    }

    /// A resource in the interface language. For a word that means two things in English
    /// ("Take": a recording, or an opinion), a `LocalizedStringResource` with its own key and the
    /// English as `defaultValue` gets a translation for each meaning.
    nonisolated init(inInterfaceLanguage resource: LocalizedStringResource) {
        var resource = resource
        if let locale = InterfaceLocale.current {
            resource.locale = locale
        }
        self.init(localized: resource)
    }

    /// A string written in `language` rather than the interface's: text Cue puts into a script
    /// (a draft built from a brief, the sponsorship disclosure) is in the script's language. Nil
    /// uses the interface language.
    nonisolated init(localized keyAndValue: String.LocalizationValue, writtenIn language: CueLanguage?, comment: StaticString? = nil) {
        var resource = LocalizedStringResource(keyAndValue, comment: comment)
        if let language {
            resource.locale = Locale(identifier: language.interfaceLocalization)
        } else if let locale = InterfaceLocale.current {
            resource.locale = locale
        }
        self.init(localized: resource)
    }
}
