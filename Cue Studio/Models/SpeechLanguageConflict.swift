//
//  SpeechLanguageConflict.swift
//  Cue Studio
//

import Foundation

/// Voice Following listens in one language and a take's captions in another, for the same script:
/// Voice Following in the one picked in Language & Region, captions in the script's own. Captions
/// say so, so the two never disagree silently.
nonisolated struct SpeechLanguageConflict: Equatable, Sendable {
    let voiceFollowing: CueLanguage
    let captions: CueLanguage

    var message: String {
        String(localized: "Voice Following listens in \(voiceFollowing.localizedName). Captions listen in the script’s language, \(captions.localizedName). Pick the language spoken if it’s different.")
    }
}
