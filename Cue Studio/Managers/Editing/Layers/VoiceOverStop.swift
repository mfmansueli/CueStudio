//
//  VoiceOverStop.swift
//  Cue Studio
//

import Foundation

/// Why a voice-over stopped without the creator's Stop.
nonisolated enum VoiceOverStop: Equatable, Sendable {
    /// A call, Siri or another app took the microphone: what was recorded until then is kept.
    case interrupted
    /// The recording couldn't be written (`AVAudioRecorder`'s encode error): nothing usable was kept.
    case failed
}
