//
//  CaptionRevisionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Correcting caption lines keeps the voice's times where it can and flags the rest.
@Suite("Caption revisions")
struct CaptionRevisionTests {
    private let line = CaptionCue(words: [
        CaptionWord(text: "Hoje", start: 1, end: 1.3),
        CaptionWord(text: "vou", start: 1.4, end: 1.6),
        CaptionWord(text: "mostrar", start: 1.7, end: 2.1),
        CaptionWord(text: "duas", start: 2.2, end: 2.5),
    ])

    @Test func aSpellingFixKeepsEveryTime() {
        let fixed = CaptionRevision.retimed(line, text: "Hoje vou mostrar DUAS")
        #expect(fixed.words.map(\.start) == line.words.map(\.start))
        #expect(!fixed.needsTimingReview)
        #expect(fixed.isRevised)
        #expect(fixed.hasWordTiming)
        #expect(fixed.id == line.id)
    }

    @Test func aNewWordGetsAGuessedTimeAndTheLineAsksForAReview() {
        let fixed = CaptionRevision.retimed(line, text: "Hoje eu vou mostrar duas")
        #expect(fixed.words.map(\.text) == ["Hoje", "eu", "vou", "mostrar", "duas"])
        #expect(fixed.words[1].isEstimated)
        #expect(fixed.words[1].start >= 1.3 - 0.000_001 && fixed.words[1].end <= 1.4 + 0.000_001)
        #expect(fixed.words[2].start == 1.4)
        #expect(fixed.needsTimingReview)
        #expect(!fixed.hasWordTiming)
    }

    @Test func aLineTimedAsAWholeKeepsItsTime() {
        let legacy = CaptionCue(text: "Old line", start: 3, end: 5, origin: .legacy)
        let fixed = CaptionRevision.retimed(legacy, text: "Old line, fixed")
        #expect(fixed.start == 3 && fixed.end == 5)
        #expect(fixed.words.isEmpty)
    }

    @Test func splittingUsesTheWordTimes() throws {
        let (first, second) = try #require(CaptionRevision.split(line, beforeWord: 2))
        #expect(first.text == "Hoje vou")
        #expect(first.end == 1.6)
        #expect(second.text == "mostrar duas")
        #expect(second.start == 1.7)
        #expect(second.end == line.end)
        #expect(first.id == line.id && second.id != line.id)
        #expect(CaptionRevision.split(line, beforeWord: 0) == nil)
    }

    @Test func splittingALineWithoutWordTimesSharesItByLengthAndAsksForAReview() throws {
        let legacy = CaptionCue(text: "aa bb", start: 0, end: 4, origin: .legacy)
        let (first, second) = try #require(CaptionRevision.split(legacy, beforeWord: 1))
        #expect(first.end == 2)
        #expect(second.start == 2)
        #expect(first.needsTimingReview && second.needsTimingReview)
    }

    @Test func mergingJoinsWordsAndTimes() throws {
        let (first, second) = try #require(CaptionRevision.split(line, beforeWord: 2))
        let merged = CaptionRevision.merged(first, second)
        #expect(merged.text == "Hoje vou mostrar duas")
        #expect(merged.words == line.words)
        #expect(merged.start == line.start && merged.end == line.end)
    }

    @Test func aLineSavedBeforeWordsReadsAsLegacy() throws {
        let json = #"{"text": "Hi there", "start": 1, "end": 2}"#
        let cue = try JSONDecoder().decode(CaptionCue.self, from: Data(json.utf8))
        #expect(cue.origin == .legacy)
        #expect(cue.words.isEmpty)
        #expect(!cue.isRevised)
        #expect(!cue.hasWordTiming)
    }

    @Test func theTranscriptKeepsWhatWasHeard() {
        let transcript = CaptionTranscript(words: line.words, languageCode: "pt")
        #expect(transcript.text(in: TimeSpan(start: 1.65, end: 2.6)) == "mostrar duas")
    }
}
