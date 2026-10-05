//
//  TranscriptTimingCheckTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Times that don't fit the recording are spread over the spoken stretch and marked estimated, never kept as measured.
@Suite("TranscriptTimingCheck")
struct TranscriptTimingCheckTests {
    private func words(_ count: Int, from start: TimeInterval, to end: TimeInterval) -> [TimedWord] {
        let step = (end - start) / Double(count)
        return (0..<count).map { TimedWord(text: "w\($0)", start: start + Double($0) * step, end: start + Double($0 + 1) * step) }
    }

    @Test func timesThatFitTheSpeechAreLeftAlone() {
        let heard = words(30, from: 0.1, to: 9.8)
        let result = TranscriptTimingCheck.reconciled(heard, spoken: TimeSpan(start: 0, end: 10))
        #expect(result == heard)
        #expect(result.allSatisfy { !$0.isEstimated })
    }

    /// Hindi's dictation model on an iPhone: 25 words timed inside the first 5.3 s of 10.4 s of speech.
    @Test func wordsTimedInHalfTheSpeechAreSpreadAndMarkedEstimated() throws {
        let heard = words(25, from: 0, to: 5.28)
        let result = TranscriptTimingCheck.reconciled(heard, spoken: TimeSpan(start: 0.05, end: 10.36))
        #expect(result.allSatisfy { $0.isEstimated })
        let first = try #require(result.first)
        let last = try #require(result.last)
        #expect(abs(first.start - 0.05) < 0.001 && abs(last.end - 10.36) < 0.001)
        #expect(zip(result, result.dropFirst()).allSatisfy { $0.end <= $1.start + 0.0001 })
    }

    @Test func aShortTakeOrFewWordsSayNothing() {
        let few = words(4, from: 0, to: 2)
        #expect(TranscriptTimingCheck.reconciled(few, spoken: TimeSpan(start: 0, end: 10)) == few)
        let brief = words(10, from: 0, to: 1)
        #expect(TranscriptTimingCheck.reconciled(brief, spoken: TimeSpan(start: 0, end: 2.5)) == brief)
        #expect(TranscriptTimingCheck.reconciled(brief, spoken: nil) == brief)
    }

    @Test func theSpokenStretchComesFromTheLevels() {
        // 0.05 s readings: quiet, speech from 0.2 s to 0.6 s, quiet.
        let levels: [Float] = [-80, -80, -80, -80] + Array(repeating: -20, count: 8) + [-80, -80]
        let span = TranscriptTimingCheck.spokenSpan(levels: levels, interval: 0.05)
        #expect(abs((span?.start ?? 0) - 0.2) < 0.0001 && abs((span?.end ?? 0) - 0.6) < 0.0001)
        #expect(TranscriptTimingCheck.spokenSpan(levels: [-80, -90], interval: 0.05) == nil)
    }
}
