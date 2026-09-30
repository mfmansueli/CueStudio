//
//  CaptionOutcome.swift
//  Cue Studio
//

import Foundation

/// What listening to a take for captions ended with.
nonisolated enum CaptionOutcome: Equatable, Sendable {
    /// Lines from the voice, and what was heard word by word (kept apart from corrections).
    case captions([CaptionCue], transcript: CaptionTranscript)
    /// The take has no sound.
    case noAudio
    /// There is sound, but no words were heard.
    case noSpeech
    /// No speech model on this device can listen in the language (never another one instead).
    case unavailable(SpeechUnavailableReason)
}
