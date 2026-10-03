//
//  LocalizedBundle.swift
//  Cue Studio
//

import Foundation
import ObjectiveC

/// Lets Cue switch its interface language while running. `String(localized:)` and SwiftUI look up
/// strings in `Bundle.main`, which picks its language once, at launch; once activated, the main
/// bundle answers from the chosen language's `.lproj` instead. The next launch doesn't need it: the
/// system list (`AppleLanguages`) already starts the app in that language.
///
/// The main bundle's class becomes this subclass, which only overrides string lookup; everything
/// else is the normal `Bundle`.
nonisolated final class LocalizedBundle: Bundle, @unchecked Sendable {
    // Read from any thread by string lookups; written only by `activate(_:)`.
    private static let state = Storage()

    static var isActive: Bool { state.bundle != nil }

    /// Answers from `localization`'s `.lproj` from now on. Ignored when the app doesn't ship it.
    static func activate(_ localization: String) {
        guard let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return }
        if !(Bundle.main is LocalizedBundle) {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }
        state.bundle = bundle
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = Self.state.bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }

    /// The active `.lproj` bundle behind a lock.
    nonisolated private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Bundle?

        var bundle: Bundle? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }
}
