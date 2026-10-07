//
//  CameraControlling.swift
//  Cue Studio
//

import AVFAudio

/// What the prompter needs from the camera. Tests drive the recording flow with a fake.
protocol CameraControlling: AnyObject {
    var status: CameraStatus { get }
    /// The camera in use. Can differ from the one asked for when that one isn't on this device.
    var activeLens: CameraLens? { get }
    /// The background effect for the next takes (this session only): shown live while recording
    /// and saved with the take as a recipe, the recording itself untouched.
    var background: BackgroundEffect { get }

    func start(with settings: CameraSettings) async
    /// Applies lens, format and connection changes to a running session.
    func apply(_ settings: CameraSettings) async
    func stop() async
    func startRecording(settings: CameraSettings) async throws
    /// Nil when the recording failed.
    func stopRecording() async -> RecordedClip?
    /// Sends the microphone audio to `handler` (on an audio queue), for Voice follow's speech
    /// recognition. Nil stops it.
    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?)
    /// Sends each microphone buffer's level to `handler` (on an audio queue) as it arrives, for
    /// Voice follow's speaking indicator. Nil stops it.
    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?)
    /// Called when a take ends without Stop: the storage filled up or a call took the camera. The clip is what could be saved.
    var onRecordingEnded: (@MainActor (RecordedClip?, RecordingEndReason) -> Void)? { get set }
}
