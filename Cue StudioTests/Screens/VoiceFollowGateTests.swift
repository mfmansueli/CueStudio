//
//  VoiceFollowGateTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("VoiceFollowGate")
struct VoiceFollowGateTests {
    @Test func loudInputIsSpeech() {
        var gate = VoiceFollowGate()
        let speaking = gate.isSpeaking(level: -20, at: 0)
        #expect(speaking)
    }

    @Test func shortGapsKeepScrolling() {
        var gate = VoiceFollowGate()
        _ = gate.isSpeaking(level: -20, at: 0)
        let speaking = gate.isSpeaking(level: -60, at: 0.5)
        #expect(speaking)
    }

    @Test func realPausesStopScrolling() {
        var gate = VoiceFollowGate()
        _ = gate.isSpeaking(level: -20, at: 0)
        let speaking = gate.isSpeaking(level: -60, at: 0.7)
        #expect(!speaking)
    }

    @Test func silenceBeforeSpeakingIsNotSpeech() {
        var gate = VoiceFollowGate()
        let withoutLevel = gate.isSpeaking(level: nil, at: 0)
        let quiet = gate.isSpeaking(level: -80, at: 1)
        #expect(!withoutLevel)
        #expect(!quiet)
    }

    @Test func normalizedLevelMapsToZeroToOne() {
        #expect(VoiceFollowGate.normalized(-50) == 0)
        #expect(VoiceFollowGate.normalized(0) == 1)
        #expect(VoiceFollowGate.normalized(-25) == 0.5)
        #expect(VoiceFollowGate.normalized(nil) == 0)
    }
}
