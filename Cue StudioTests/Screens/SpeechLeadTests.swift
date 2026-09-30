//
//  SpeechLeadTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("SpeechLead")
struct SpeechLeadTests {
    /// Advances `lead` frame by frame (60 a second) from `start` for `seconds`, with the voice
    /// quiet for `quiet` seconds (nil: not speaking).
    private func run(_ lead: inout SpeechLead, from start: TimeInterval, for seconds: TimeInterval, quiet: TimeInterval? = 0) {
        for frame in 0...Int(seconds * 60) {
            lead.advance(to: start + Double(frame) / 60, quiet: quiet)
        }
    }

    @Test func speakingMovesAheadRightAway() {
        var lead = SpeechLead()
        run(&lead, from: 0, for: 0.2)
        // 2.5 words a second, for 0.2 s.
        #expect(abs(lead.position - 0.5) < 0.05)
    }

    @Test func neverMoreThanTheMaximumPastTheLastWord() {
        var lead = SpeechLead()
        run(&lead, from: 0, for: 5)
        #expect(lead.position == 2)
        lead.confirm(1, at: 5)
        run(&lead, from: 5, for: 5)
        #expect(lead.position == 3)
    }

    @Test func aPauseHoldsIt() {
        var lead = SpeechLead()
        run(&lead, from: 0, for: 0.2)
        let before = lead.position
        run(&lead, from: 0.2, for: 1, quiet: 0.5)
        #expect(lead.position == before)
        run(&lead, from: 1.2, for: 1, quiet: nil)
        #expect(lead.position == before)
    }

    /// Recognition catching up leaves the text where the prediction had it: never back.
    @Test func aConfirmationBehindThePredictionKeepsThePosition() {
        var lead = SpeechLead()
        run(&lead, from: 0, for: 0.6)
        let predicted = lead.position
        lead.confirm(1, at: 0.6)
        #expect(lead.confirmed == 1)
        #expect(abs(lead.position - predicted) < 0.0001)
    }

    /// Recognition going further than the prediction takes the text with it.
    @Test func aConfirmationAheadOfThePredictionWins() {
        var lead = SpeechLead()
        run(&lead, from: 0, for: 0.2)
        lead.confirm(5, at: 0.2)
        #expect(lead.position == 5)
    }

    @Test func thePaceIsMeasuredFromTheWordsHeard() {
        var lead = SpeechLead()
        lead.initialRate = 2
        lead.confirm(2, at: 1)
        for second in 2...12 { lead.confirm(2 + 4 * (second - 1), at: Double(second)) }
        #expect(lead.rate > 3.5)
        #expect(lead.rate <= SpeechLead.rateRange.upperBound)
    }

    @Test func aResetForgetsThePrediction() {
        var lead = SpeechLead()
        run(&lead, from: 0, for: 1)
        lead.reset(to: 10)
        #expect(lead.position == 10)
        // The first frame after a reset only starts the clock: no jump.
        lead.advance(to: 5, quiet: 0)
        #expect(lead.position == 10)
    }

    @Test func noLeadWaitsForEveryWord() {
        var lead = SpeechLead()
        lead.maximumWords = 0
        run(&lead, from: 0, for: 2)
        #expect(lead.position == 0)
    }
}
