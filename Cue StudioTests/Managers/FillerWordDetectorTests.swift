//
//  FillerWordDetectorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("FillerWordDetector")
struct FillerWordDetectorTests {
    /// Words said at the given times, each lasting a quarter second (exact in binary, so spans
    /// compare exactly).
    private func said(_ words: [(String, TimeInterval)]) -> [TimedWord] {
        words.map { TimedWord(text: $0.0, start: $0.1, end: $0.1 + 0.25) }
    }

    @Test func hesitationSoundsAreSuggested() {
        let words = said([("So", 0), ("um,", 0.25), ("today", 0.5), ("we", 0.75)])
        let found = FillerWordDetector.suggestions(in: words, languageCode: "en")
        #expect(found.count == 1)
        #expect(found[0].kind == .filler)
        #expect(found[0].span == TimeSpan(start: 0.25, end: 0.5))
        #expect(found[0].text == "um,")
        #expect(found[0].confidence == FillerWordDetector.soundConfidence)
        // Nothing is removed by finding it.
        #expect(found[0].status == .pending)
    }

    @Test func aHeldSoundIsTheSameSound() {
        let found = FillerWordDetector.suggestions(in: said([("Ummmm", 0), ("okay", 0.25)]), languageCode: "en")
        #expect(found.map(\.text) == ["Ummmm"])
    }

    @Test func likeWithMeaningStays() {
        let words = said([("I", 0), ("like", 0.25), ("this", 0.5)])
        #expect(FillerWordDetector.suggestions(in: words, languageCode: "en").isEmpty)
    }

    @Test func likeBetweenPausesIsSuggestedLessSurely() {
        let words = said([("it", 0), ("was,", 0.25), ("like,", 1.0), ("huge", 1.75)])
        let found = FillerWordDetector.suggestions(in: words, languageCode: "en")
        #expect(found.map(\.text) == ["like,"])
        #expect(found[0].confidence == FillerWordDetector.phraseConfidence)
    }

    @Test func phrasesOfSeveralWordsAreOneSuggestion() {
        let words = said([("and", 0), ("you", 0.75), ("know", 1.0), ("it", 1.75)])
        let found = FillerWordDetector.suggestions(in: words, languageCode: "en")
        #expect(found.count == 1)
        #expect(found[0].span == TimeSpan(start: 0.75, end: 1.25))
        #expect(found[0].text == "you know")
    }

    @Test func anExclamationIsNeverAFiller() {
        let words = said([("Ah!", 0), ("Agora", 0.75), ("entendi!", 1.0)])
        #expect(FillerWordDetector.suggestions(in: words, languageCode: "pt").isEmpty)
    }

    @Test func portugueseFillers() {
        let words = said([("Hoje", 0), ("eu", 0.25), ("queria...", 0.5), ("hã", 1.25), ("tipo", 2.0), ("falar", 2.75)])
        let found = FillerWordDetector.suggestions(in: words, languageCode: "pt")
        #expect(found.map(\.text) == ["hã", "tipo"])
    }

    @Test func anUnknownLanguageFindsNothing() {
        #expect(FillerWordDetector.suggestions(in: said([("um", 0)]), languageCode: "xx").isEmpty)
    }
}
