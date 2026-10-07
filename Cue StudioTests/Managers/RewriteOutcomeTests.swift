//
//  RewriteOutcomeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A tool's result is held to what its name says (`RewriteOutcome`).
@Suite("Rewrite outcome")
struct RewriteOutcomeTests {
    private static func words(_ count: Int) -> String {
        (0..<count).map { "w\($0)" }.joined(separator: " ")
    }

    @Test func shorterHasToBeShorter() {
        let before = Self.words(100)
        #expect(RewriteOutcome.judge(.shorterAndDirect, before: before, after: Self.words(60)) == .kept)
        #expect(RewriteOutcome.judge(.shorterAndDirect, before: before, after: Self.words(95)) == .tooLong(words: 95, wanted: 90))
        #expect(RewriteOutcome.judge(.shorterAndDirect, before: before, after: Self.words(10)) == .tooShort(words: 10, wanted: 45))
        #expect(RewriteOutcome.judge(.shorterAndDirect, before: before, after: before) == .tooLong(words: 100, wanted: 90))
    }

    @Test func aTinyTextOnlyHasToNotGrow() {
        #expect(RewriteOutcome.judge(.shorterAndDirect, before: "Hello there friends.", after: "Hello friends.") == .kept)
        #expect(RewriteOutcome.judge(.shorterAndDirect, before: "Hello there friends.", after: "Hello there my dear friends.") != .kept)
    }

    @Test func fixGrammarKeepsTheLength() {
        let before = Self.words(100)
        #expect(RewriteOutcome.judge(.fixGrammar, before: before, after: Self.words(100) + " extra") == .kept)
        #expect(RewriteOutcome.judge(.fixGrammar, before: before, after: Self.words(50)) == .tooShort(words: 50, wanted: 85))
        #expect(RewriteOutcome.judge(.fixGrammar, before: before, after: Self.words(150)) == .tooLong(words: 150, wanted: 116))
    }

    @Test func fixingNothingIsAnAnswer() {
        let text = "I tried cold showers for thirty days."
        let outcome = RewriteOutcome.judge(.fixGrammar, before: text, after: "I tried cold showers for thirty days!")
        #expect(outcome == .unchanged)
        #expect(outcome.isAcceptable(for: .fixGrammar))
        #expect(!outcome.isAcceptable(for: .moreEnergy))
    }

    @Test func inMyVoiceKeepsAboutTheLength() {
        let before = Self.words(132)
        #expect(RewriteOutcome.judge(.inMyVoice, before: before, after: Self.words(40)) != .kept)
        // A concise voice says it in half the words and still keeps the points.
        #expect(RewriteOutcome.judge(.inMyVoice, before: before, after: Self.words(70)) == .kept)
        #expect(RewriteOutcome.judge(.inMyVoice, before: before, after: Self.words(120)) == .kept)
    }

    @Test func fitToTimeLandsInTheRangeWithSomeSlack() {
        let before = Self.words(300)
        #expect(RewriteOutcome.judge(.fitToTime, before: before, after: Self.words(180), target: 150...225) == .kept)
        #expect(RewriteOutcome.judge(.fitToTime, before: before, after: Self.words(240), target: 150...225) == .kept)
        #expect(RewriteOutcome.judge(.fitToTime, before: before, after: Self.words(300), target: 150...225) == .tooLong(words: 300, wanted: 259))
        #expect(RewriteOutcome.judge(.fitToTime, before: before, after: Self.words(100), target: 150...225) == .tooShort(words: 100, wanted: 127))
    }

    @Test func theCorrectionSaysWhatWentWrongInNumbers() {
        let text = RewriteOutcome.tooShort(words: 188, wanted: 318).correction(for: .fixGrammar, sourceWords: 374, allowed: 318...430)
        #expect(text.contains("188") && text.contains("374") && text.contains("318") && text.contains("430"))
    }

    @Test func cuesAreNotWordsAndAreNotLost() {
        let before = "Hello [pause] there my friend, how are you doing today. [smile]"
        #expect(RewriteOutcome.judge(.fixGrammar, before: before, after: "Hello [pause] there my friend, how are you doing today. [smile]") == .unchanged)
        #expect(RewriteOutcome.judge(.fixGrammar, before: before, after: "Hello there my friend, how are you doing today.") == .lostCues(had: 2, kept: 0))
        #expect(RewriteOutcome.judge(.fixGrammar, before: before, after: "Hi [pause] there my friend, how are you doing today. [smile]") == .kept)
        #expect(RewriteOutcome.judge(.translate, before: before, after: "Hola, amigo mío, ¿cómo estás hoy?") != .lostCues(had: 2, kept: 0))
    }

    // MARK: - Invented cues

    @Test func aSceneTheModelMadeUpIsTakenOut() {
        let after = "[Scene: Interior, morning light streaming through curtains.]\n\nI don’t know why, but my mornings were a mess."
        let before = "i dont know why but my mornings was a mess."
        #expect(RewriteOutcome.withoutInventedCues(after, comparedTo: before) == "I don’t know why, but my mornings were a mess.")
    }

    @Test func theCuesTheScriptHadStay() {
        let before = "Hello. [pause] Welcome back. [Look at camera]"
        let after = "Hello. [pause] Welcome back! [look  at camera] [sound of a bell]"
        #expect(RewriteOutcome.withoutInventedCues(after, comparedTo: before) == "Hello. [pause] Welcome back! [look at camera]")
    }

    @Test func aTextWithNothingInventedIsLeftAlone() {
        let after = "First paragraph.\n\nSecond paragraph. [smile]"
        #expect(RewriteOutcome.withoutInventedCues(after, comparedTo: "First paragraph.\n\nSecond paragraph. [smile]") == after)
    }

    @Test func aParagraphThatWasOnlyAnInventedCueGoesWithIt() {
        let after = "One.\n\n[Music swells]\n\nTwo."
        #expect(RewriteOutcome.withoutInventedCues(after, comparedTo: "One.\n\nTwo.") == "One.\n\nTwo.")
    }
}
