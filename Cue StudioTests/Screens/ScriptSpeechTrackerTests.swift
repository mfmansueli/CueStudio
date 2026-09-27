//
//  ScriptSpeechTrackerTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptSpeechTracker")
struct ScriptSpeechTrackerTests {
    private static let script = """
        Hi, I'm Ana and today I'm showing you three habits that changed my mornings.
        First, I drink a glass of water before coffee. Second, I stretch for five minutes.
        Third, I write down one goal for the day.
        """

    private func makeTracker(_ text: String = script) -> ScriptSpeechTracker {
        ScriptSpeechTracker(words: ScriptWords(text: text).tokens)
    }

    private func index(of word: String, in text: String = script) -> Int {
        ScriptWords(text: text).tokens.firstIndex(of: word) ?? -1
    }

    @Test func followsTheReadingWordByWord() {
        var tracker = makeTracker()
        tracker.hear("Hi, I'm Ana")
        #expect(tracker.position == 3)
        tracker.hear("Hi, I'm Ana and today")
        #expect(tracker.position == 5)
    }

    @Test func aWordStillBeingSaidCounts() {
        var tracker = makeTracker()
        tracker.hear("hi im ana and tod")
        #expect(tracker.position == 5)
    }

    @Test func misheardWordsDoNotStopIt() {
        var tracker = makeTracker()
        tracker.hear("hi I'm Anna and today I'm showing")
        #expect(tracker.position == 7)
    }

    @Test func talkOffScriptIsIgnored() {
        var tracker = makeTracker()
        let moved = tracker.hear("okay let me check the lighting real quick")
        #expect(!moved)
        #expect(tracker.position == 0)
    }

    @Test func rereadingDoesNotMoveBack() {
        var tracker = makeTracker()
        tracker.hear("hi I'm Ana and today I'm showing you three habits")
        let position = tracker.position
        tracker.hear("hi I'm Ana and today I'm showing you three habits hi I'm Ana")
        #expect(tracker.position == position)
    }

    @Test func skippingASentenceJumpsAhead() {
        var tracker = makeTracker()
        tracker.hear("three habits that changed my mornings")
        #expect(tracker.position == index(of: "first"))
        tracker.hear("changed my mornings second I stretch for five")
        #expect(tracker.position == index(of: "minutes"))
    }

    @Test func aStrayCommonWordDoesNotPullFarAhead() {
        var tracker = makeTracker()
        let moved = tracker.hear("before")
        #expect(!moved)
        #expect(tracker.position == 0)
    }

    @Test func repeatedPhrasesMatchTheNearestOne() {
        var tracker = makeTracker("Say it again. Say it again. Then stop.")
        tracker.hear("say it again")
        #expect(tracker.position == 3)
        tracker.hear("say it again say it again")
        #expect(tracker.position == 6)
    }

    @Test func readingTheLastWordsFinishes() {
        var tracker = makeTracker()
        tracker.reset(to: index(of: "third"))
        tracker.hear("third I write down one goal for the day")
        #expect(tracker.position == tracker.words.count)
        let moved = tracker.hear("thanks for watching")
        #expect(!moved)
    }

    @Test func resetIsClamped() {
        var tracker = makeTracker()
        tracker.reset(to: 1000)
        #expect(tracker.position == tracker.words.count)
        tracker.reset(to: -3)
        #expect(tracker.position == 0)
    }
}
