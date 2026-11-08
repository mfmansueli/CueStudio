//
//  CleanUpStartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The start row (D9): the silence before the first word is trimmed to a moment before the first sound, never into it, from
/// where the edit starts now, and never under a text or video the creator put there.
@Suite("Clean up start")
struct CleanUpStartTests {
    /// A 10 s take that opens on 1.8 s of silence (the detector's pause, padding inside).
    private let opening = CleanUpSuggestion(
        kind: .pause, span: TimeSpan(start: 0 + SilenceDetector.padding, end: 1.8 - SilenceDetector.padding), confidence: 0.9
    )
    private let words = [CaptionWord(text: "Today", start: 1.9, end: 2.2), CaptionWord(text: "I'll", start: 2.2, end: 2.4)]

    @Test func itTrimsToAMarginBeforeTheFirstSound() throws {
        let proposal = try #require(CleanUpStart.proposal(
            timeline: EditTimeline(sourceDuration: 10), pauses: [opening], words: words, visualStarts: []
        ))
        // The silence ends at 1.8 (before the word's 1.9): the earlier of the two, less the margin.
        #expect(abs(proposal.to - (1.8 - CleanUpStart.margin)) < 0.000_1)
        #expect(abs(proposal.saving - 1.6) < 0.000_1)
        #expect(proposal.firstWord == "Today")
        #expect(!proposal.keepsIntro)
        let trimmed = try #require(CleanUpStart.trimmed(EditTimeline(sourceDuration: 10), to: proposal))
        #expect(abs(trimmed.editedDuration - 8.4) < 0.000_1)
    }

    @Test func aWordHeardEarlierThanTheSilenceEndsMovesTheStartEarlier() throws {
        let early = [CaptionWord(text: "So", start: 1.2, end: 1.5)]
        let proposal = try #require(CleanUpStart.proposal(
            timeline: EditTimeline(sourceDuration: 10), pauses: [opening], words: early, visualStarts: []
        ))
        #expect(abs(proposal.to - 1.0) < 0.000_1)
    }

    @Test func lessThanThreeTenthsOfSilenceIsNoRow() {
        let short = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 0.12, end: 0.16), confidence: 0.4)
        #expect(CleanUpStart.proposal(timeline: EditTimeline(sourceDuration: 10), pauses: [short], words: [], visualStarts: []) == nil)
    }

    @Test func itStartsFromWhereTheEditStartsNow() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 1.0)
        let proposal = try #require(CleanUpStart.proposal(timeline: timeline, pauses: [opening], words: words, visualStarts: []))
        #expect(abs(proposal.from - 1.0) < 0.000_1)
        #expect(abs(proposal.saving - 0.6) < 0.000_1)
        // Past the silence already: no row.
        timeline.trimStart(to: 1.7)
        #expect(CleanUpStart.proposal(timeline: timeline, pauses: [opening], words: words, visualStarts: []) == nil)
    }

    @Test func aTitleOnTheStartKeepsIt() throws {
        let proposal = try #require(CleanUpStart.proposal(
            timeline: EditTimeline(sourceDuration: 10), pauses: [opening], words: words, visualStarts: [0.2]
        ))
        #expect(proposal.keepsIntro)
        // A text that starts after what would go doesn't stop it.
        let later = CleanUpStart.proposal(timeline: EditTimeline(sourceDuration: 10), pauses: [opening], words: words, visualStarts: [1.7])
        #expect(later?.keepsIntro == false)
    }

    @Test func aMontageOpeningOnAnotherVideoIsLeftAlone() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.insertClip(source: UUID(), duration: 5, at: 0)
        #expect(CleanUpStart.proposal(timeline: timeline, pauses: [opening], words: words, visualStarts: []) == nil)
    }
}
