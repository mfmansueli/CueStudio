//
//  MicrophoneAccess.swift
//  Cue Studio
//

import AVFAudio

/// The microphone permission, as dictation asks about it: it only asks when the creator taps the
/// microphone, and never again once it was refused (Settings is where that changes).
struct MicrophoneAccess {
    /// True once the creator refused it (or turned it off in Settings).
    var isDenied: @MainActor () -> Bool = { AVAudioApplication.shared.recordPermission == .denied }
    /// Asks, showing the system prompt only the first time. True when allowed.
    var request: @MainActor () async -> Bool = { await AVAudioApplication.requestRecordPermission() }
}
