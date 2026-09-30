//
//  PlaybackAudioSession.swift
//  Cue Studio
//

/// Prepares audible video playback without depending on the audio session left by recording.
@MainActor
protocol PlaybackAudioSession: AnyObject {
    func prepareForPlayback() async
}
