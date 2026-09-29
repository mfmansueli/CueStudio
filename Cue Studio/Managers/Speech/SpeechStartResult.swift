//
//  SpeechStartResult.swift
//  Cue Studio
//

import Foundation

/// How starting Voice Following's recognition went.
nonisolated enum SpeechStartResult: Sendable {
    /// Listening, in `route`'s language.
    case listening(SpeechTranscription, SpeechRoute)
    /// Recognition can't follow the words here; the reason says why, for the creator.
    case unavailable(SpeechUnavailableReason)
    /// Something newer (a stop, another start) came first.
    case cancelled
}
