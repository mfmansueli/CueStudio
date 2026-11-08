//
//  ScriptRetakeDetectorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The lines of the script said more than once (plan §10): every try identified, none marked to go, the last not assumed best.
@Suite("Script retakes")
struct ScriptRetakeDetectorTests {
    private let script = "Today I'll show you three habits. They changed my mornings forever."

    /// Words said one after the other, a third of a second each.
    private func said(_ text: String, from start: TimeInterval = 0) -> [TimedWord] {
        text.split(separator: " ").enumerated().map { index, word in
            TimedWord(text: String(word), start: start + Double(index) / 3, end: start + Double(index) / 3 + 0.3)
        }
    }

    @Test func aLineSaidThreeTimesIsThreeTriesOfOneGroup() throws {
        let words = said("Today I'll show you uh Today I'll show you three Today I'll show them three habits. They changed my mornings forever.")
        let tries = ScriptRetakeDetector.suggestions(in: words, script: script)
        #expect(tries.count == 3)
        #expect(tries.allSatisfy { $0.kind == .retake && !$0.isSure })
        let group = try #require(tries.first?.attempt?.group)
        #expect(tries.allSatisfy { $0.attempt?.group == group && $0.attempt?.count == 3 })
        #expect(tries.map { $0.attempt?.number } == [1, 2, 3])
        #expect(tries.first?.attempt?.line == "Today I'll show you three habits.")
        // The tries follow each other, without overlapping.
        for (earlier, later) in zip(tries, tries.dropFirst()) { #expect(earlier.span.end <= later.span.start + 0.001) }
    }

    @Test func aTakeSaidOnceHasNoTries() {
        let words = said("Today I'll show you three habits. They changed my mornings forever.")
        #expect(ScriptRetakeDetector.suggestions(in: words, script: script).isEmpty)
    }

    @Test func noScriptNoTries() {
        let words = said("Today I'll show you Today I'll show you three habits.")
        #expect(ScriptRetakeDetector.suggestions(in: words, script: "").isEmpty)
    }

    @Test func theAnalyzerKeepsTheTriesAndDropsTheRepeatTheyContain() {
        let words = said("Today I'll show you Today I'll show you three habits. They changed my mornings forever.")
        let found = CleanUpAnalyzer.suggestions(silences: [], transcript: TakeTranscript(words: words, languageCode: "en"), script: script)
        let tries = found.filter { $0.attempt != nil }
        #expect(tries.count == 2)
        // A plain repeat over the same words isn't listed a second time.
        let plain = found.filter { $0.kind == .retake && $0.attempt == nil }
        #expect(plain.allSatisfy { repeated in !tries.contains { $0.span.overlaps(repeated.span) } })
    }

    @Test func aNameHeardDifferentlyStillOpensTheLine() {
        let script = "Gridley placed a stake in the ground. Then he left."
        let words = said("Gitley placed a stake Gitley placed a stake in the ground. Then he left.")
        #expect(ScriptRetakeDetector.suggestions(in: words, script: script).count == 2)
    }

    @Test func anEverydayPhraseWithoutTheLinesFirstWordIsNoTry() {
        let script = "So I think that this works. Then we go home."
        let words = said("I think that is fine and I think that this works. Then we go home.")
        #expect(ScriptRetakeDetector.suggestions(in: words, script: script).isEmpty)
    }

    @Test func aDandaAndAnArabicQuestionMarkEndALine() {
        #expect(ScriptRetakeDetector.lines(in: "यह पहला वाक्य है। यह दूसरा वाक्य है।").count == 2)
        #expect(ScriptRetakeDetector.lines(in: "هل هذا أول سطر؟ وهذا هو الثاني").count == 2)
    }
}
