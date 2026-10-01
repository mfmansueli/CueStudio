//
//  SilenceDetectorTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("SilenceDetector")
struct SilenceDetectorTests {
    private func levels(_ pattern: [(Float, Int)]) -> [Float] {
        pattern.flatMap { Array(repeating: $0.0, count: $0.1) }
    }

    @Test func longPausesBecomePaddedSilences() {
        // 1 s of speech, 1 s of quiet, 1 s of speech, at 0.1 s per reading.
        let silences = SilenceDetector.silences(levels: levels([(-20, 10), (-60, 10), (-20, 10)]), interval: 0.1)
        #expect(silences.count == 1)
        // A breath of 0.12 s stays on each side.
        #expect(abs(silences[0].start - 1.12) < 0.001)
        #expect(abs(silences[0].end - 1.88) < 0.001)
    }

    @Test func breathsBetweenWordsAreNeverSuggested() {
        #expect(SilenceDetector.silences(levels: levels([(-20, 10), (-60, 2), (-20, 10)]), interval: 0.1).isEmpty)
    }

    @Test func shortPausesAreFoundForTheThreshold() {
        // Half a second: under the default "Ignore pauses under 0.7s", but found.
        let silences = SilenceDetector.silences(levels: levels([(-20, 10), (-60, 5), (-20, 10)]), interval: 0.1)
        #expect(silences.count == 1)
        #expect(abs(SilenceDetector.silenceLength(ofCut: silences[0]) - 0.5) < 0.001)
    }

    @Test func trailingSilenceCounts() {
        let silences = SilenceDetector.silences(levels: levels([(-20, 5), (-80, 20)]), interval: 0.1)
        #expect(silences.count == 1)
        #expect(abs(SilenceDetector.totalDuration(of: silences) - 1.76) < 0.001)
    }
}
