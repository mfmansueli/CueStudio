//
//  WordBoundariesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Words that run into each other meet where the voice dips between them, never farther than `reach` from the recognizer's
/// edge; a pause between words, and estimated times, stay as they are.
@Suite("WordBoundaries")
struct WordBoundariesTests {
    /// 10 ms readings: voice at -12 dBFS with a dip at 0.65–0.66 s, 50 ms after the recognizer's shared edge at 0.60 s.
    private let levels: [Float] = (0..<200).map { $0 == 65 ? -40 : -12 }

    @Test func aSharedEdgeMovesToTheDip() {
        let words = [TimedWord(text: "perdeu", start: 0.3, end: 0.6), TimedWord(text: "o", start: 0.6, end: 0.9)]
        let moved = WordBoundaries.atQuietestPoints(words, levels: levels, interval: 0.01)
        #expect(abs(moved[0].end - 0.655) < 0.0001 && abs(moved[1].start - 0.655) < 0.0001)
        #expect(moved[0].start == 0.3 && moved[1].end == 0.9 && !moved[1].isEstimated)
    }

    @Test func aDipOutOfReachIsLeft() {
        let far: [Float] = (0..<200).map { $0 == 75 ? -40 : -12 }
        let words = [TimedWord(text: "a", start: 0.3, end: 0.6), TimedWord(text: "b", start: 0.6, end: 0.9)]
        // No dip within 80 ms: the recognizer's edge stays.
        #expect(WordBoundaries.atQuietestPoints(words, levels: far, interval: 0.01) == words)
    }

    @Test func aPauseAndEstimatedTimesStay() {
        let paused = [TimedWord(text: "a", start: 0.3, end: 0.5), TimedWord(text: "b", start: 0.7, end: 0.9)]
        #expect(WordBoundaries.atQuietestPoints(paused, levels: levels, interval: 0.01) == paused)
        let estimated = [
            TimedWord(text: "a", start: 0.3, end: 0.6, isEstimated: true), TimedWord(text: "b", start: 0.6, end: 0.9, isEstimated: true),
        ]
        #expect(WordBoundaries.atQuietestPoints(estimated, levels: levels, interval: 0.01) == estimated)
        #expect(WordBoundaries.atQuietestPoints(paused, levels: [], interval: 0.01) == paused)
    }

    /// Five 10 ms readings make the 50 ms one, by their power.
    @Test func readingsCombineByPower() {
        let combined = AudioLevelReader.combined([-20, -20, -20, -20, -20, -120], every: 5)
        #expect(combined.count == 2 && abs(combined[0] + 20) < 0.001)
    }
}
