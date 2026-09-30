//
//  VoiceFollowGateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("VoiceFollowGate")
struct VoiceFollowGateTests {
    /// A camera buffer: 1024 frames at 48 kHz.
    private let buffer = 1024.0 / 48_000

    /// Feeds `level` in camera-sized buffers from `start` for `seconds`; returns whether the gate
    /// said "speaking" at each one.
    private func feed(_ gate: inout VoiceFollowGate, level: Float, from start: TimeInterval, for seconds: TimeInterval) -> [Bool] {
        stride(from: start + buffer, through: start + seconds, by: buffer).map { time in
            gate.hear(level: level, at: time, duration: buffer)
        }
    }

    @Test func loudInputIsSpeechWithinTwoBuffers() {
        var gate = VoiceFollowGate()
        let first = gate.hear(level: -20, at: buffer, duration: buffer)
        let second = gate.hear(level: -20, at: 2 * buffer, duration: buffer)
        #expect(!first)
        #expect(second)
    }

    /// Studio's meter delivers 100 ms buffers: one is long enough to count.
    @Test func aLongBufferCountsAtOnce() {
        var gate = VoiceFollowGate()
        let speaking = gate.hear(level: -20, at: 0.1, duration: 0.1)
        #expect(speaking)
    }

    @Test func shortGapsKeepScrolling() {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -20, from: 0, for: 0.2)
        let speaking = gate.hear(level: -60, at: 0.7, duration: buffer)
        #expect(speaking)
        #expect(gate.isSpeaking(at: 0.75))
    }

    @Test func realPausesStopScrolling() {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -20, from: 0, for: 0.2)
        let speaking = gate.hear(level: -60, at: 0.9, duration: buffer)
        #expect(!speaking)
        #expect(!gate.isSpeaking(at: 0.9))
    }

    @Test func silenceBeforeSpeakingIsNotSpeech() {
        var gate = VoiceFollowGate()
        #expect(!gate.isSpeaking(at: 0))
        let quiet = feed(&gate, level: -80, from: 0, for: 2)
        #expect(quiet.allSatisfy { !$0 })
    }

    /// A click or a knock on the desk fills one buffer: not enough to light the indicator.
    @Test func aClickIsNotSpeech() {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -70, from: 0, for: 1)
        let click = gate.hear(level: -15, at: 1 + buffer, duration: buffer)
        let after = gate.hear(level: -70, at: 1 + 2 * buffer, duration: buffer)
        #expect(!click)
        #expect(!after)
    }

    /// In a quiet room the threshold is the one Voice Following always had.
    @Test func aQuietRoomKeepsTheUsualThreshold() {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -65, from: 0, for: 4)
        #expect(gate.effectiveThreshold == -40)
        let speech = feed(&gate, level: -38, from: 4, for: 0.2)
        #expect(speech.last == true)
    }

    /// A fan or air conditioning louder than the threshold stops counting once the room's level is
    /// learned; speech above it still counts.
    @Test func steadyRoomNoiseIsLearnedAndIgnored() throws {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -36, from: 0, for: 4)
        let floor = try #require(gate.noiseFloor)
        #expect(abs(floor - -36) < 0.01)
        #expect(gate.effectiveThreshold == -26)
        let noise = feed(&gate, level: -36, from: 4, for: 2)
        let speech = feed(&gate, level: -18, from: 6, for: 0.2)
        #expect(noise.allSatisfy { !$0 })
        #expect(speech.last == true)
    }

    /// Speech with gaps between words keeps the room's floor where it is.
    @Test func speakingDoesNotRaiseTheFloor() throws {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -60, from: 0, for: 2)
        var time = 2.0
        for _ in 0..<20 {
            _ = feed(&gate, level: -20, from: time, for: 0.25)
            _ = feed(&gate, level: -58, from: time + 0.25, for: 0.08)
            time += 0.33
        }
        let floor = try #require(gate.noiseFloor)
        #expect(floor < -55)
        #expect(gate.effectiveThreshold == -40)
    }

    @Test func quietTimeCountsFromTheLastLoudBuffer() {
        var gate = VoiceFollowGate()
        _ = feed(&gate, level: -20, from: 0, for: 0.2)
        let last = gate.quietTime(at: 0.2)
        #expect(last != nil && last! < 0.03)
        #expect(abs((gate.quietTime(at: 0.5) ?? 0) - 0.3) < 0.03)
        #expect(gate.quietTime(at: 2) == nil)
    }

    @Test func normalizedLevelMapsToZeroToOne() {
        #expect(VoiceFollowGate.normalized(-50) == 0)
        #expect(VoiceFollowGate.normalized(0) == 1)
        #expect(VoiceFollowGate.normalized(-25) == 0.5)
        #expect(VoiceFollowGate.normalized(nil) == 0)
    }
}
