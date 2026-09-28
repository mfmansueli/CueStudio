//
//  RetakeDetectorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("RetakeDetector")
struct RetakeDetectorTests {
    /// Words said at the given times, each lasting a quarter second (exact in binary, so spans
    /// compare exactly).
    private func said(_ words: [(String, TimeInterval)]) -> [TimedWord] {
        words.map { TimedWord(text: $0.0, start: $0.1, end: $0.1 + 0.25) }
    }

    @Test func aRestartPhraseTakesBackTheAttemptBeforeIt() {
        let words = said([
            ("So.", 0),
            ("The", 1.0), ("best", 1.25), ("wey", 1.5), ("let", 1.75), ("me", 2.0), ("start", 2.25), ("again.", 2.5),
            ("The", 3.5), ("best", 3.75), ("way", 4.0),
        ])
        let found = RetakeDetector.suggestions(in: words, languageCode: "en")
        #expect(found.count == 1)
        #expect(found[0].kind == .retake)
        // From the first word after the pause before it to the end of "again".
        #expect(found[0].span == TimeSpan(start: 1.0, end: 2.75))
        #expect(found[0].text == "The best wey let me start again.")
        #expect(found[0].confidence == RetakeDetector.phraseConfidence)
    }

    @Test func wordsSaidTwiceDropTheFirstTry() {
        let words = said([
            ("Today", 0), ("I", 0.25), ("want,", 0.5), ("today", 1.0), ("I", 1.25), ("want", 1.5), ("to", 1.75), ("talk", 2.0),
        ])
        let found = RetakeDetector.suggestions(in: words, languageCode: "en")
        #expect(found.count == 1)
        #expect(found[0].span == TimeSpan(start: 0, end: 1.0))
        #expect(found[0].text == "Today I want,")
        #expect(found[0].confidence == RetakeDetector.repeatConfidence)
    }

    @Test func oneWordSaidTwiceIsOnPurpose() {
        let words = said([("It's", 0), ("really", 0.25), ("really", 0.5), ("good", 0.75)])
        #expect(RetakeDetector.suggestions(in: words, languageCode: "en").isEmpty)
    }

    @Test func aShortPhraseIsLessSure() {
        let words = said([("Isso", 0), ("é...", 0.25), ("espera", 1.25), ("isso", 2.0), ("é", 2.25), ("fácil", 2.5)])
        let found = RetakeDetector.suggestions(in: words, languageCode: "pt")
        #expect(found.count == 1)
        #expect(found[0].text == "espera")
        #expect(found[0].confidence == RetakeDetector.shortPhraseConfidence)
    }

    @Test func aRestartNeverReachesTooFarBack() {
        // 60 words with no pause, then "start over".
        var words = (0..<60).map { TimedWord(text: "word\($0)", start: Double($0) * 0.35, end: Double($0) * 0.35 + 0.3) }
        words += said([("start", 21), ("over", 21.25)])
        let found = RetakeDetector.suggestions(in: words, languageCode: "en")
        #expect(found.count == 1)
        #expect(found[0].span.end == 21.5)
        #expect(21 - found[0].span.start <= RetakeDetector.maximumTakeBack)
    }
}
