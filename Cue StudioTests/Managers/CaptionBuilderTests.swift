//
//  CaptionBuilderTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("CaptionBuilder")
struct CaptionBuilderTests {
    private func word(_ text: String, _ start: Double) -> TimedWord {
        TimedWord(text: text, start: start, end: start + 0.3)
    }

    @Test func heardWordsTakeTheScriptsSpelling() {
        let heard = [word("okay", 0), word("real", 0.4), word("talk", 0.8)]
        let captions = CaptionBuilder.captions(heard: heard, script: "[confident] Okay, real talk. [pause]")
        #expect(captions == [CaptionCue(text: "Okay, real talk.", start: 0, end: 1.1)])
    }

    @Test func captionsBreakAfterFiveWordsSentencesAndPauses() {
        let words = ["one", "two", "three", "four", "five", "six."].enumerated().map { word($1, Double($0) * 0.4) }
            + [word("later", 5)]
        let captions = CaptionBuilder.group(words)
        #expect(captions.map(\.text) == ["one two three four five", "six.", "later"])
    }

    @Test func withoutTimingTheScriptIsSpreadOverTheTake() {
        let captions = CaptionBuilder.captions(script: "One two three four five six seven eight nine ten.", duration: 10)
        #expect(captions.count == 2)
        #expect(captions.first?.start == 0)
        #expect(captions.last?.end == 10)
    }

    @Test func runsWithSeveralWordsShareTheirTime() {
        let words = CaptionTranscriber.spread("hey there", start: 1, end: 2)
        #expect(words == [TimedWord(text: "hey", start: 1, end: 1.5), TimedWord(text: "there", start: 1.5, end: 2)])
    }
}
