//
//  CameraControlling.swift
//  Cue Studio
//

import AVFAudio

/// What the prompter needs from the camera. Tests drive the recording flow with a fake.
protocol CameraControlling: AnyObject {
    var status: CameraStatus { get }
    var isRecording: Bool { get }

    func start(with settings: CameraSettings) async
    /// Applies lens, format and connection changes to a running session.
    func apply(_ settings: CameraSettings) async
    func stop() async
    func startRecording(settings: CameraSettings) async throws
    /// Nil when the recording failed.
    func stopRecording() async -> RecordedClip?
    /// Recorded audio power in dBFS, for Voice follow. Nil without audio.
    func audioPowerLevel() async -> Float?
    /// Sends the microphone audio to `handler` (on an audio queue), for Voice follow's speech
    /// recognition. Nil stops it.
    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?)
}
