//
//  AudioLevelMetering.swift
//  Cue Studio
//

import AVFAudio

/// Live microphone level and audio, for Voice follow when the camera is off.
protocol AudioLevelMetering: AnyObject {
    /// Average input power in dBFS. Nil while not metering.
    var powerLevel: Float? { get }
    func startMetering() async -> Bool
    func stopMetering()
    /// Sends the microphone audio to `handler` (on the audio thread) while metering. Nil stops it.
    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?)
}
