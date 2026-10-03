//
//  VoiceFollowingLanguage.swift
//  Cue Studio
//

import Foundation

/// What Voice Following listens for. By default it follows each script's language (the language set
/// on the script, or the one its text is written in), which is how it always worked. Picking a
/// language makes it listen for that one whatever the script or the interface is in.
///
/// Cue never guesses the spoken language from the audio: Apple's on-device recognition needs the
/// language up front, and a wrong guess would stop the text.
nonisolated enum VoiceFollowingLanguage: Hashable, Sendable {
    case sameAsScript
    case language(CueLanguage)

    /// How it is stored: "script", or the language's identifier.
    var storageValue: String {
        switch self {
        case .sameAsScript: "script"
        case .language(let language): language.rawValue
        }
    }

    init(storageValue: String?) {
        if let storageValue, let language = CueLanguage(rawValue: storageValue) {
            self = .language(language)
        } else {
            self = .sameAsScript
        }
    }

    var language: CueLanguage? {
        if case .language(let language) = self { return language }
        return nil
    }

    var label: String {
        switch self {
        case .sameAsScript: String(localized: "Same as script")
        case .language(let language): language.nativeName
        }
    }
}
