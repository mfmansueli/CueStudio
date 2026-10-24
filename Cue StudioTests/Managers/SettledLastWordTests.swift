//
//  SettledLastWordTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A result that ends with its last word twice, first closing the sentence, becomes one word, as said; a real word after a
/// sentence's end, an abbreviation's, or one in a writing without capitals stays.
@Suite("SettledLastWord")
struct SettledLastWordTests {
    private func words(_ heard: [(String, Double, Double)]) -> [TimedWord] {
        heard.map { TimedWord(text: $0.0, start: $0.1, end: $0.2) }
    }

    @Test func aLastWordHeardTwiceIsOneWord() {
        // As an iPhone 15 Pro heard a German reading (human-de-DE-2).
        let heard = words([("gezeichnet", 10.80, 11.22), ("wurde.", 11.22, 11.52), ("wurde", 11.52, 11.82)])
        #expect(SettledLastWord.applied(to: heard) == words([("gezeichnet", 10.80, 11.22), ("wurde.", 11.22, 11.82)]))
    }

    @Test func theSettledSpellingIsKept() {
        // human-es-ES-1: "vida." was the first guess, "viaje." the word said.
        let heard = words([("de", 11.22, 11.42), ("vida.", 11.42, 11.52), ("viaje.", 11.52, 12.42)])
        #expect(SettledLastWord.applied(to: heard) == words([("de", 11.22, 11.42), ("viaje.", 11.42, 12.42)]))
    }

    @Test func aWordThatIsntTheLastOrStartsASentenceStays() {
        let newSentence = words([("wurde.", 1, 1.3), ("Wurde", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: newSentence) == newSentence)
        let notLast = words([("wurde.", 1, 1.3), ("wurde", 1.3, 1.6), ("gestern", 1.6, 2)])
        #expect(SettledLastWord.applied(to: notLast) == notLast)
        let noSentenceEnd = words([("very", 1, 1.3), ("very", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: noSentenceEnd) == noSentenceEnd)
    }

    @Test func aWordAfterAnAbbreviationStays() {
        let abbreviation = words([("e.g.", 1, 1.3), ("this", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: abbreviation) == abbreviation)
        let unlike = words([("etc.", 1, 1.3), ("too", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: unlike) == unlike)
        let short = words([("Dr.", 1, 1.3), ("dre", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: short) == short)
        let otherSound = words([("verlassen.", 1, 1.3), ("worden", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: otherSound) == otherSound)
    }

    @Test func aWritingWithoutCapitalsIsLeftAlone() {
        let japanese = words([("です。", 1, 1.3), ("です", 1.3, 1.6)])
        #expect(SettledLastWord.applied(to: japanese) == japanese)
        #expect(SettledLastWord.applied(to: words([("wurde.", 1, 1.3)])).count == 1)
    }
}
