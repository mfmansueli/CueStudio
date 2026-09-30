//
//  AudioLevelMetering.swift
//  Cue Studio
//

import AVFAudio

/// Live microphone level and audio, for Voice follow when the camera is off.
protocol AudioLevelMetering: AnyObject {
    func startMetering() async -> Bool
    func stopMetering()
    /// Sends the microphone audio to `handler` (on the audio thread) while metering. Nil stops it.
    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?)
    /// Sends each buffer's level to `handler` (on the audio thread) as it arrives, while metering.
    /// Nil stops it.
    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?)
}
