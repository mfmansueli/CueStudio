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

    @Test func aNewWordTakesItsPlaceInTheSilenceAndTheLineKeepsFollowingTheVoice() {
        let fixed = CaptionRevision.retimed(line, text: "Hoje eu vou mostrar duas")
        #expect(fixed.words.map(\.text) == ["Hoje", "eu", "vou", "mostrar", "duas"])
        #expect(fixed.words[1].start >= 1.3 - 0.000_001 && fixed.words[1].end <= 1.4 + 0.000_001)
        #expect(fixed.words[2].start == 1.4)
        #expect(!fixed.words[1].isEstimated)
        #expect(!fixed.needsTimingReview)
        #expect(fixed.hasWordTiming)
    }

    @Test func aNewWordBetweenWordsSaidBackToBackSharesTheWordBeforeIt() {
        let tight = CaptionCue(words: [
            CaptionWord(text: "Hoje", start: 1, end: 1.5),
            CaptionWord(text: "vou", start: 1.5, end: 2),
        ])
        let fixed = CaptionRevision.retimed(tight, text: "Hoje eu vou")
        #expect(fixed.words.count == 3)
        #expect(fixed.words[0].end == fixed.words[1].start)
        #expect(fixed.words[1].end <= fixed.words[2].start)
        #expect(fixed.words[1].end - fixed.words[1].start > 0.05)
        #expect(fixed.hasWordTiming)
    }

    @Test func aWordWithNoRoomAtAllIsAGuessAndAsksForAReview() {
        let sliver = CaptionCue(words: [
            CaptionWord(text: "a", start: 1, end: 1.02),
            CaptionWord(text: "b", start: 1.02, end: 1.04),
        ])
        let fixed = CaptionRevision.retimed(sliver, text: "a x b")
        #expect(fixed.words[1].isEstimated)
        #expect(fixed.needsTimingReview)
    }

    @Test func replacingWordsKeepsTheStretchTheVoiceSpentOnThem() {
        let fixed = CaptionRevision.retimed(line, text: "Hoje vou mostrar tres coisas")
        #expect(fixed.words.map(\.text) == ["Hoje", "vou", "mostrar", "tres", "coisas"])
        #expect(fixed.words[3].start == 2.2)
        #expect(abs(fixed.words[4].end - 2.5) < 0.000_001)
        #expect(fixed.words[3].end <= fixed.words[4].start + 0.000_001)
        #expect(fixed.hasWordTiming)
        // A line with fewer words than it was heard with closes the gap, keeping order.
        let shorter = CaptionRevision.retimed(line, text: "Hoje mostrar duas")
        #expect(shorter.words.map(\.start) == [1, 1.7, 2.2])
        #expect(shorter.hasWordTiming)
    }

    @Test func editingTheTextKeepsTheLineItselfSoItsStyleStaysOnIt() {
        let fixed = CaptionRevision.retimed(line, text: "Hoje vou mostrar tres")
        #expect(fixed.id == line.id && fixed.origin == line.origin && fixed.sourceID == line.sourceID)
        #expect(fixed.start == line.start && fixed.end == line.end)
    }

    @Test func movingOrTrimmingALineFoldsItsWordsInWithoutAskingForAReview() {
        var trimmed = line
        trimmed.end = 2.3
        let fitted = CaptionRevision.fitted(trimmed)
        #expect(fitted.words.map(\.start) == [1, 1.4, 1.7, 2.2])
        #expect(fitted.words.allSatisfy { $0.end <= 2.3 })
        #expect(abs(fitted.words[3].end - 2.3) < 0.000_001)
        #expect(fitted.hasWordTiming)
        trimmed.end = 2.1
        #expect(CaptionRevision.fitted(trimmed).needsTimingReview)
    }

    @Test func linesHeardBeforeContinuationEllipsesWereDroppedLoseThemOnlyWhenUntouched() {
        var heard = CaptionCue(words: [
            CaptionWord(text: "é", start: 0, end: 0.2),
            CaptionWord(text: "interessante...", start: 0.2, end: 0.9),
        ])
        #expect(CaptionRevision.withoutContinuation(heard).text == "é interessante")
        #expect(CaptionRevision.withoutContinuation(heard).words.map(\.text) == ["é", "interessante"])
        heard.isRevised = true
        #expect(CaptionRevision.withoutContinuation(heard).text == "é interessante...")
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
