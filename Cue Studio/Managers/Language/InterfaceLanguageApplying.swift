//
//  InterfaceLanguageApplying.swift
//  Cue Studio
//

import Foundation

/// Puts Cue's interface in a language. The real one (`InterfaceLanguageStore`) switches the strings
/// right away and tells the system, so the next launch starts in it; tests use a fake.
protocol InterfaceLanguageApplying {
    /// The language the system will start Cue in, from its per-app language list. It changes when
    /// the creator picks a language for Cue in the iPhone's Settings.
    var systemAppLanguage: String? { get }
    /// Switches the interface. `nil` follows the iPhone's language again. Returns the localization
    /// the running app now shows, or nil when it was left to the system untouched (no language was
    /// ever picked in this session).
    func apply(_ localization: String?) -> String?
}
