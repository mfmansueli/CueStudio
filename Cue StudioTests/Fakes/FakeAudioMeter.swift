//
//  FakeAudioMeter.swift
//  Cue StudioTests
//

import AVFAudio
@testable import Cue_Studio

@MainActor
final class FakeAudioMeter: AudioLevelMetering {
    private(set) var isMetering = false
    private(set) var audioHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private(set) var levelHandler: (@Sendable (AudioLevelSample) -> Void)?

    func startMetering() async -> Bool {
        isMetering = true
        return true
    }

    func stopMetering() {
        isMetering = false
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        audioHandler = handler
    }

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {
        levelHandler = handler
    }

    /// A meter buffer (100 ms, like the audio engine's tap) at `level` dBFS, arriving at `time`.
    func hear(level: Float, at time: TimeInterval, duration: TimeInterval = 0.1) {
        levelHandler?(AudioLevelSample(level: level, time: time, duration: duration))
    }
}
