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
}
