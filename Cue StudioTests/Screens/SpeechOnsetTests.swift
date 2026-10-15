//
//  SpeechOnsetTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What starts Voice Following's text when the words can't be recognized: a voice, not a click, a bump or a cough.
@Suite("SpeechOnset")
struct SpeechOnsetTests {
    private let buffer = 1.0 / 60

    /// Buffers from `start` for `seconds`, loud or not.
    private func hear(_ onset: inout SpeechOnset, from start: TimeInterval, for seconds: Double, loud: Bool) {
        for frame in 1...Int((seconds * 60).rounded()) {
            onset.hear(isLoud: loud, at: start + Double(frame) * buffer, duration: buffer)
        }
    }

    @Test func silenceNeverStartsIt() {
        var onset = SpeechOnset()
        hear(&onset, from: 0, for: 10, loud: false)
        #expect(!onset.hasStarted)
    }

    /// A click or a bump: loud for a tenth of a second, then quiet again.
    @Test func anIsolatedSpikeDoesNotStartIt() {
        var onset = SpeechOnset()
        hear(&onset, from: 0, for: 0.1, loud: true)
        hear(&onset, from: 0.1, for: 3, loud: false)
        #expect(!onset.hasStarted)
    }

    /// Spikes a second apart never add up: each is out of the window before the next.
    @Test func spikesFarApartDoNotAddUp() {
        var onset = SpeechOnset()
        for second in 0..<10 {
            hear(&onset, from: Double(second), for: 0.1, loud: true)
            hear(&onset, from: Double(second) + 0.1, for: 0.9, loud: false)
        }
        #expect(!onset.hasStarted)
    }

    /// Words with the short gaps between them start it within a third of a second.
    @Test func speechStartsItQuickly() {
        var onset = SpeechOnset()
        hear(&onset, from: 0, for: 0.15, loud: true)
        hear(&onset, from: 0.15, for: 0.05, loud: false)
        #expect(!onset.hasStarted)
        hear(&onset, from: 0.2, for: 0.15, loud: true)
        #expect(onset.hasStarted)
    }

    @Test func onceStartedItStaysUntilReset() {
        var onset = SpeechOnset()
        hear(&onset, from: 0, for: 0.5, loud: true)
        hear(&onset, from: 0.5, for: 5, loud: false)
        #expect(onset.hasStarted)
        onset.reset()
        #expect(!onset.hasStarted)
        hear(&onset, from: 6, for: 0.1, loud: true)
        #expect(!onset.hasStarted)
    }
}
