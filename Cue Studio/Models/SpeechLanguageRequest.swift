//
//  SpeechLanguageRequest.swift
//  Cue Studio
//

import Foundation

/// The language Voice Following (and captions, and Clean Up) listens for, before asking the device
/// what it can recognize (`SpeechLocaleResolver`).
nonisolated enum SpeechLanguageRequest: Hashable, Sendable {
    /// Listen in this language, and only this one.
    case language(CueLanguage)
    /// Listen in the language the text is written in (a script on Auto-detect), in the creator's
    /// regional variant when one of `systemLanguages` (the iPhone's, never the interface's) has it.
    /// With no text (a freestyle take), the iPhone's first language.
    case detect(text: String, systemLanguages: [String])

    /// The Voice Following language wins; "Same as script" uses the script's, and a script on
    /// Auto-detect is read from its text. The interface language never takes part.
    init(voiceFollowing: CueLanguage?, scriptLanguage: CueLanguage?, scriptText: String, systemLanguages: [String]) {
        if let language = voiceFollowing ?? scriptLanguage {
            self = .language(language)
        } else {
            self = .detect(text: scriptText, systemLanguages: systemLanguages)
        }
    }

    /// Before Language & Region existed: the script's language, read from its text, in the
    /// iPhone's regional variant. Kept as the default for code that has no settings to read.
    static func script(_ script: Script?) -> SpeechLanguageRequest {
        SpeechLanguageRequest(
            voiceFollowing: nil, scriptLanguage: script?.language,
            scriptText: script?.text ?? "", systemLanguages: Locale.preferredLanguages
        )
    }
}
