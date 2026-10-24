//
//  TranscriptTimingCheckTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Times that don't fit the recording are spread over the spoken stretch and marked estimated, never kept as measured; the
/// stretch is read against the room's own noise; no word starts in the silence before the voice.
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

    /// A FLEURS reading on an iPhone: two seconds of hiss at −42 dBFS, then the voice. The hiss isn't speech.
    @Test func aRoomsHissIsntTakenForSpeech() throws {
        let levels: [Float] = Array(repeating: -42, count: 40) + Array(repeating: -12, count: 160) + Array(repeating: -43, count: 10)
        let span = try #require(TranscriptTimingCheck.spokenSpan(levels: levels, interval: 0.05))
        #expect(abs(span.start - 2) < 0.0001 && abs(span.end - 10) < 0.0001)
    }

    @Test func aClickBeforeTheVoiceIsntSpeech() throws {
        let levels: [Float] = [-30] + Array(repeating: -50, count: 20) + Array(repeating: -15, count: 40)
        let span = try #require(TranscriptTimingCheck.spokenSpan(levels: levels, interval: 0.05))
        #expect(abs(span.start - 1.05) < 0.0001)
    }

    /// A take that is speech almost throughout still has a spoken stretch, and a quiet room keeps the quiet room's level.
    @Test func aTakeThatIsAllSpeechStillHasAStretch() throws {
        let levels: [Float] = (0..<200).map { $0.isMultiple(of: 7) ? -24 : -14 }
        let span = try #require(TranscriptTimingCheck.spokenSpan(levels: levels, interval: 0.05))
        #expect(span.start < 0.1 && span.end > 9.9)
        #expect(TranscriptTimingCheck.level(for: [-120, -120, -120, -5]) == TranscriptTimingCheck.speechLevel)
    }

    /// Measured times in a hissy room are kept: three seconds of hiss on each side (a fixed level heard 12 s of speech and
    /// spread the 6 s of words over them) don't make the speech look longer than the words.
    @Test func measuredTimesInAHissyRoomStayMeasured() throws {
        let levels: [Float] = Array(repeating: -40, count: 60) + Array(repeating: -12, count: 120) + Array(repeating: -40, count: 60)
        let heard = words(16, from: 3, to: 9)
        let result = TranscriptTimingCheck.reconciled(heard, spoken: TranscriptTimingCheck.spokenSpan(levels: levels, interval: 0.05))
        #expect(result == heard)
    }

    /// Korean's transcriber on an iPhone: the first word timed from 0.00 s, the voice at 2.40 s.
    @Test func theFirstWordStartsWithTheVoice() {
        let spoken = TimeSpan(start: 2.4, end: 10.7)
        let heard = [
            TimedWord(text: "1940년", start: 0, end: 3.36), TimedWord(text: "8월", start: 3.36, end: 3.72),
            TimedWord(text: "15일", start: 3.72, end: 4.26),
        ]
        let result = TranscriptTimingCheck.startingWithTheVoice(heard, spoken: spoken)
        #expect(result[0].start == 2.4 && result[0].end == 3.36 && !result[0].isEstimated)
        #expect(Array(result.dropFirst()) == Array(heard.dropFirst()))
        // A little early is the recognizer's to keep; nothing without a voice changes.
        let early = [TimedWord(text: "Hi", start: 2.2, end: 2.8)]
        #expect(TranscriptTimingCheck.startingWithTheVoice(early, spoken: spoken) == early)
        #expect(TranscriptTimingCheck.startingWithTheVoice(heard, spoken: nil) == heard)
    }
}
