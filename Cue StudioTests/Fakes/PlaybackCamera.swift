//
//  PlaybackCamera.swift
//  Cue StudioTests
//

import AVFAudio
@testable import Cue_Studio

/// A camera whose microphone is a recording: `play(_:)` feeds it through the app's own
/// `AudioBufferTap` in real time, so Voice Following hears it exactly as it hears the capture
/// session in Selfie mode.
@MainActor
final class PlaybackCamera: CameraControlling {
    var status: CameraStatus = .running
    private(set) var isRecording = false
    var activeLens: CameraLens? = .front
    var background = BackgroundEffect()
    let tap = AudioBufferTap()

    func start(with settings: CameraSettings) async {}
    func apply(_ settings: CameraSettings) async {}
    func stop() async {}

    func startRecording(settings: CameraSettings) async throws {
        isRecording = true
    }

    func stopRecording() async -> RecordedClip? {
        isRecording = false
        return nil
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        tap.setHandler(handler)
    }

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {
        tap.setLevelHandler(handler)
    }

    /// Starts the recording. Returns the uptime at which its first buffer's audio begins.
    func play(_ fixture: SpeechFixture) -> (start: TimeInterval, playback: AudioPlayback) {
        let playback = AudioPlayback(fixture) { [tap] buffer in tap.receive(buffer) }
        return (playback.start(), playback)
    }
}
