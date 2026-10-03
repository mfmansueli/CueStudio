//
//  SpeechLanguageRequest.swift
//  Cue Studio
//

import Foundation

/// The language one recognition should listen in, resolved from the Voice Following setting and the
/// script. Never from the interface language: the app can be in English while the creator speaks
/// Portuguese.
nonisolated enum SpeechLanguageRequest: Equatable, Sendable {
    /// The creator picked the language, for Voice Following or for the script.
    case language(CueLanguage)
    /// Nothing picked one: the language the script is written in, detected from its text (Voice
    /// Following's original behavior, kept for scripts without a language).
    case detectFromScript

    /// Voice Following's own language wins; "Same as script" uses the script's language when it has
    /// one, and its text otherwise.
    static func resolve(voiceFollowing: VoiceFollowingLanguage, scriptLanguage: CueLanguage?) -> SpeechLanguageRequest {
        switch voiceFollowing {
        case .language(let language): .language(language)
        case .sameAsScript: scriptLanguage.map { .language($0) } ?? .detectFromScript
        }
    }
}
