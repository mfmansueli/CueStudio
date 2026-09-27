//
//  FakeAudioMeter.swift
//  Cue StudioTests
//

import AVFAudio
@testable import Cue_Studio

@MainActor
final class FakeAudioMeter: AudioLevelMetering {
    var powerLevel: Float?
    private(set) var isMetering = false
    private(set) var audioHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?

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
}
