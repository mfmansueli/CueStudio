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

    // MARK: - Words the script keeps repeating

    /// "the", "de", "e": heard anywhere in talk that isn't the script, they match everywhere in it.
    @Test func scatteredCommonWordsFromOffScriptTalkDoNotPullTheTextAhead() {
        let text = """
            The first habit is the water. The second is the walk, and the third is the list of the day.
            Every morning I take the time to drink the water, then the walk, then the list, and the day starts.
            By the end of the week the habit is the one thing that the day needs.
            """
        var tracker = makeTracker(text)
        for talk in ["so the", "so the and the", "yes the a the and", "uh the is the to the"] {
            tracker.hear(talk)
        }
        #expect(tracker.position <= 4, "Filler moved the text to word \(tracker.position)")
    }

    @Test func aCleanReadingStillFollowsEveryWordWhenTheScriptRepeatsWords() {
        let text = "I drink the water and I write the goal and I walk the block. I like the water, the goal and the walk."
        let tokens = ScriptWords(text: text).tokens
        var tracker = ScriptSpeechTracker(words: tokens)
        var heard: [String] = []
        for (index, token) in tokens.enumerated() {
            heard.append(token)
            tracker.hear(heard.joined(separator: " "))
            // Never behind by more than a word, and never ahead of what was said.
            #expect(tracker.position <= index + 1)
            #expect(tracker.position >= index, "At word \(index + 1) the text was at \(tracker.position)")
        }
        #expect(tracker.position == tokens.count)
    }

    @Test func skippedWordsAndSelfCorrectionsStillFollowTheReader() {
        var tracker = makeTracker()
        // Omits "that changed" and false-starts the next phrase.
        tracker.hear("Hi I'm Ana and today I'm showing you three habits my mornings")
        #expect(tracker.position == index(of: "mornings") + 1)
        tracker.hear("Hi I'm Ana and today I'm showing you three habits my mornings first I I drink")
        #expect(tracker.position == index(of: "drink") + 1)
        // Takes it back ("no, first, I drink a glass"): the text doesn't go back.
        tracker.hear("my mornings first I I drink no first I drink a glass")
        #expect(tracker.position == index(of: "glass") + 1)
    }

    // MARK: - Numbers and names

    @Test func aNumberIsTheSameInDigitsAndInWords() {
        let text = "I stretch for 5 minutes and write 3 goals."
        var tracker = ScriptSpeechTracker(words: ScriptWords(text: text, language: .english).tokens, language: .english)
        tracker.hear("I stretch for five minutes and write three goals")
        #expect(tracker.position == ScriptWords(text: text, language: .english).count)
        let portuguese = "Eu alongo por 5 minutos e escrevo 3 metas."
        var other = ScriptSpeechTracker(words: ScriptWords(text: portuguese, language: .portugueseBrazil).tokens, language: .portugueseBrazil)
        other.hear("eu alongo por cinco minutos e escrevo três metas")
        #expect(other.position == ScriptWords(text: portuguese, language: .portugueseBrazil).count)
    }

    @Test func aMisheardNameStillCountsAsTheName() {
        var tracker = ScriptSpeechTracker(words: ScriptWords(text: "Hi I'm Priyanka and today I show three habits").tokens)
        tracker.hear("hi I'm Prianca and today")
        #expect(tracker.position == 5)
    }
}
