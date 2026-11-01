//
//  Script+ReadTime.swift
//  Cue Studio
//

import Foundation

nonisolated extension Script {
    /// The language whose pace times this script (`ReadTime.pace(for:)`): its own, or read from its words when it has none (a script the
    /// creator wrote), the same way in the list and on the page.
    var paceLanguage: CueLanguage? { language ?? LanguageDetector.quickLanguage(in: text) }

    /// How long the script runs at the natural speaking pace of its language.
    var readSeconds: TimeInterval { ReadTime.seconds(for: text, language: paceLanguage) }
}
