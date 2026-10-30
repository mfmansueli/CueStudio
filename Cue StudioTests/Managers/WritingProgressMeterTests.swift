//
//  WritingProgressMeterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The meter a page hands to the writer: it expects the fewest words the creator asked for and reads its own clock.
@MainActor
@Suite("Writing progress meter")
struct WritingProgressMeterTests {
    @Test func itExpectsTheFewestWordsTheCreatorAskedFor() {
        let request = ScriptRequest(source: .prompt("Why I quit coffee"), platform: .tiktok, tone: nil, voice: nil, targetRange: 60...90)
        let meter = WritingProgressMeter(for: request)
        #expect(meter.estimate.expectedWords == ReadTime.words(for: 60))
    }

    @Test func itClimbsOnItsOwnClockAndEndsAtOneHundredPercent() {
        var time: TimeInterval = 50
        let meter = WritingProgressMeter(expectedWords: 100, now: { time })
        #expect(meter.fraction == 0)
        meter.record(.drafting)
        time += 1
        #expect(meter.fraction > 0)
        meter.record(.wrote(words: 50))
        #expect(abs(meter.fraction - 0.45) < 1e-9)
        #expect(!meter.isFinished)
        meter.finish()
        #expect(meter.fraction == 1 && meter.isFinished)
    }

    /// Ultra AI's three passes: the percentage is where the arcs are (`UltraPassOrbit`), never ahead of them as the words' estimate was (82%
    /// with the check just begun, 29/10/2026), and never 100% before the script is there.
    @Test func inPassesThePercentageFollowsTheArcs() {
        var time: TimeInterval = 50
        let meter = WritingProgressMeter(expectedWords: 100, now: { time })
        meter.begin(pass: 0, of: 3)
        meter.record(.wrote(words: 100))
        meter.advance(pass: 1)
        #expect(abs(meter.fraction - 1.0 / 3) < 1e-9)
        meter.begin(pass: 1, of: 3)
        meter.record(.lengthening(done: 10, of: 200))
        #expect(abs(meter.fraction - 1.0 / 3) < 1e-9, "the check has just begun")
        time += 7
        #expect(meter.fraction > 1.0 / 3 && meter.fraction < 0.5, "it creeps while the model thinks")
        meter.begin(pass: 2, of: 3)
        meter.advance(pass: 1)
        #expect(meter.fraction == 0.99)
        meter.finish()
        #expect(meter.fraction == 1)
    }

    /// Ultra AI's scene round the star (`UltraWaitScene`): when each pass began, and a spark for each step of its words, never one for a
    /// word that adds less than a step.
    @Test func eachPassBeginsAtItsTimeAndItsWordsArriveInSteps() {
        var time: TimeInterval = 10
        let meter = WritingProgressMeter(expectedWords: 100, now: { time })
        meter.begin(pass: 0, of: 3)
        meter.advance(pass: 0.02)
        #expect(meter.arrivals.isEmpty, "less than a step")
        time = 11
        meter.advance(pass: 0.07)
        meter.advance(pass: 0.1)
        #expect(meter.arrivals == [WritingArrival(pass: 0, fraction: 0.07, time: 11)])
        time = 14
        meter.begin(pass: 1, of: 3)
        meter.advance(pass: 0.06)
        #expect(meter.arrivals.last == WritingArrival(pass: 1, fraction: 0.06, time: 14), "a new pass counts its own steps")
        time = 20
        meter.begin(pass: 2, of: 3)
        #expect(meter.passStarts == [10, 14, 20])
    }
}
