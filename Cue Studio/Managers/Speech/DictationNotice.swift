//
//  DictationNotice.swift
//  Cue Studio
//

import Foundation

/// Why a dictation didn't start, or ended without the creator asking. It never costs anything:
/// the words already written stay, and typing works as before.
enum DictationNotice: Equatable {
    /// The creator said no to the microphone (or it's off in Settings).
    case microphoneDenied
    /// Speech recognition can't run here, for this reason.
    case unavailable(SpeechUnavailableReason)
    /// The system took the microphone away (a call, Siri, an unplugged mic, the app leaving the screen).
    case interrupted
    /// The creator stopped and nothing had been said.
    case nothingHeard

    var message: String {
        switch self {
        case .microphoneDenied:
            String(localized: "The microphone is off for Cue. Turn it on in Settings to dictate, or type your idea.")
        case .unavailable(let reason):
            reason.dictationMessage
        case .interrupted:
            String(localized: "Dictation stopped. What you said so far is kept.")
        case .nothingHeard:
            String(localized: "Didn’t catch anything. Try again, or type your idea.")
        }
    }

    /// Whether Settings is where this gets fixed.
    var offersSettings: Bool { self == .microphoneDenied }
}
