//
//  MyWordsSpellingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// My words' capitals on what was heard: a whole word only, never a near match nor an everyday word, and every word in its own
/// time.
@Suite("My words spelling")
struct MyWordsSpellingTests {
    private func heard(_ text: String) -> [CaptionWord] {
        text.split(separator: " ").enumerated().map { index, word in
            CaptionWord(text: String(word), start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4, isEstimated: index == 2)
        }
    }

    private func text(_ words: [CaptionWord]) -> String {
        words.map(\.text).joined(separator: " ")
    }

    @Test func aWholeWordTakesTheSavedCapitals() {
        let words = MyWordsSpelling.apply(to: heard("i posted it on tiktok, from my IPHONE"), myWords: ["TikTok", "iPhone"])
        #expect(text(words) == "i posted it on TikTok, from my iPhone")
    }

    @Test func onlyAWholeWordIsWritten() {
        let words = MyWordsSpelling.apply(to: heard("tiktoks and tick tock and iphones and tiktok's"), myWords: ["TikTok", "iPhone"])
        #expect(text(words) == "tiktoks and tick tock and iphones and tiktok's")
    }

    @Test func anEverydayWordIsNeverTurnedIntoABrand() {
        // "Cue", "Apple" and "US" have everyday twins: they stay hints only.
        let words = MyWordsSpelling.apply(to: heard("take your cue from an apple and tell us"), myWords: ["Cue", "Apple", "US"])
        #expect(text(words) == "take your cue from an apple and tell us")
        #expect(!MyWordsSpelling.rewrites("Cue"))
        #expect(!MyWordsSpelling.rewrites("NASA"))
        #expect(!MyWordsSpelling.rewrites("Cue Studio"))
        #expect(MyWordsSpelling.rewrites("CapCut"))
        #expect(MyWordsSpelling.rewrites("eBay"))
    }

    @Test func aCommonWordNextToASavedOneIsUntouched() {
        let words = MyWordsSpelling.apply(to: heard("open capcut and cut the clip"), myWords: ["CapCut"])
        #expect(text(words) == "open CapCut and cut the clip")
    }

    @Test func timesNeverChange() {
        let before = heard("my youtube channel on youtube")
        let after = MyWordsSpelling.apply(to: before, myWords: ["YouTube"])
        #expect(after.count == before.count)
        #expect(after.map(\.start) == before.map(\.start))
        #expect(after.map(\.end) == before.map(\.end))
        #expect(after.map(\.isEstimated) == before.map(\.isEstimated))
        #expect(text(after) == "my YouTube channel on YouTube")
    }

    @Test func withoutMyWordsNothingChanges() {
        let words = heard("tiktok and iphone")
        #expect(MyWordsSpelling.apply(to: words, myWords: []) == words)
    }

    /// The caption lines: the script lends its spelling first, then My words write their capitals; the lines keep their times.
    @Test func captionsCarryMyWordsAfterTheScript() {
        let words = heard("we edit in capcut every day")
        let lines = CaptionBuilder.captions(heard: words, script: "", myWords: ["CapCut"])
        #expect(lines.flatMap(\.words).map(\.text) == ["we", "edit", "in", "CapCut", "every", "day"])
        #expect(lines.flatMap(\.words).map(\.start) == words.map(\.start))
        let followed = CaptionBuilder.captions(heard: heard("we edit in capcut every day"), script: "We edit in Capcut every day.", myWords: ["CapCut"])
        #expect(followed.flatMap(\.words).map(\.text) == ["We", "edit", "in", "CapCut", "every", "day."])
    }
}
