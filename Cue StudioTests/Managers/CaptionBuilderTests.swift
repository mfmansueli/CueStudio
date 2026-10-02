//
//  CaptionBuilderTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Captions from what was heard: the voice decides the words and when, the script only lends its
/// spelling where it reliably matches, and lines break where a reader needs them to.
@Suite("CaptionBuilder")
struct CaptionBuilderTests {
    /// Heard words, 0.4 s apart.
    private func heard(_ line: String, from start: Double = 0) -> [CaptionWord] {
        line.split(separator: " ").enumerated().map { index, word in
            CaptionWord(text: String(word), start: start + Double(index) * 0.4, end: start + Double(index) * 0.4 + 0.3)
        }
    }

    private func text(_ heard: [CaptionWord], script: String) -> String {
        CaptionText.joined(CaptionBuilder.aligned(heard: heard, script: script).map(\.text))
    }

    @Test func heardWordsTakeTheScriptsSpelling() {
        let captions = CaptionBuilder.captions(heard: heard("okay real talk"), script: "[confident] Okay, real talk. [pause]")
        #expect(captions.map(\.text) == ["Okay, real talk."])
        #expect(captions.first?.start == 0)
        #expect(captions.first?.end == 1.1)
        #expect(captions.first?.words.count == 3)
    }

    @Test func theRecognizersContinuationEllipsesAreLeftOut() {
        let words = [
            CaptionWord(text: "é", start: 0, end: 0.2),
            CaptionWord(text: "bem", start: 0.3, end: 0.5),
            CaptionWord(text: "interessante...", start: 0.6, end: 1.2),
            CaptionWord(text: "…", start: 1.2, end: 1.3),
            CaptionWord(text: "mas", start: 1.4, end: 1.6),
        ]
        let captions = CaptionBuilder.captions(heard: words, script: "")
        #expect(captions.map(\.text) == ["é bem interessante mas"])
        #expect(captions.first?.words.count == 4)
    }

    @Test func onlyEllipsesAtTheEndOfAHeardWordGo() {
        #expect(CaptionText.withoutContinuation("interessante...") == "interessante")
        #expect(CaptionText.withoutContinuation("interessante…") == "interessante")
        #expect(CaptionText.withoutContinuation("interessante....") == "interessante")
        #expect(CaptionText.withoutContinuation("…") == "")
        #expect(CaptionText.withoutContinuation("fim.") == "fim.")
        #expect(CaptionText.withoutContinuation("fim?") == "fim?")
        #expect(CaptionText.withoutContinuation("3.5") == "3.5")
    }

    @Test func theScriptsOwnEllipsisIsKept() {
        let captions = CaptionBuilder.captions(heard: heard("bem interessante"), script: "Bem interessante... mesmo.")
        #expect(captions.first?.text.contains("...") == true)
    }

    @Test func theVoiceWinsOverTheScript() {
        // Said: "two" and "show", written: "three" and "present".
        let line = text(heard("hoje vou mostrar duas ferramentas"), script: "Hoje vou apresentar três ferramentas.")
        #expect(line == "Hoje vou mostrar duas ferramentas.")
    }

    @Test func improvisedWordsStayAndSkippedLinesDontAppear() {
        let script = "First point. Second point is long and careful. Third point."
        let line = text(heard("first point oh and by the way third point"), script: script)
        #expect(line == "First point. oh and by the way Third point.")
        #expect(!line.contains("Second"))
    }

    @Test func wordsSaidTwiceShowTwice() {
        let line = text(heard("the the plan is simple"), script: "The plan is simple.")
        #expect(CaptionText.words(in: line).count == 5)
        #expect(line.hasSuffix("plan is simple."))
    }

    @Test func negationsAndNumbersAreNeverReplaced() {
        // "go" lines up alone and is short: it stays as heard (without the script's period).
        #expect(text(heard("i will not go"), script: "I will go.") == "I will not go")
        #expect(text(heard("three quick tips"), script: "3 quick tips") == "three quick tips")
        #expect(text(heard("dois minutos"), script: "Três minutos") == "dois minutos")
    }

    @Test func aLoneShortWordDoesntTakeTheScriptsSpelling() {
        // "e" lines up by chance with the script's "é": left as heard.
        let line = text(heard("e agora"), script: "Isso é tudo. Nada mais.")
        #expect(line == "e agora")
    }

    @Test func linesBreakAfterFiveWordsSentencesAndPauses() {
        let words = heard("one two three four five six.") + [CaptionWord(text: "later", start: 5, end: 5.3)]
        let captions = CaptionBuilder.group(words)
        #expect(captions.map(\.text) == ["one two three four five", "six.", "later"])
    }

    @Test func languagesWithoutSpacesJoinWithoutSpaces() {
        let words = ["今日", "は", "いい", "天気", "です", "ね。"].enumerated().map { index, word in
            CaptionWord(text: word, start: Double(index) * 0.3, end: Double(index) * 0.3 + 0.25)
        }
        let captions = CaptionBuilder.group(words)
        #expect(captions.map(\.text) == ["今日はいい天気ですね。"])
    }

    @Test func longLinesBreakByLength() {
        let words = heard("extraordinarily unbelievable transformations happened yesterday")
        let captions = CaptionBuilder.group(words)
        #expect(captions.count > 1)
        #expect(captions.allSatisfy { CaptionText.length(CaptionText.words(in: $0.text)) <= CaptionBuilder.maximumCharacters + 16 })
    }

    @Test func aLongTakeLinesUpWithItsScript() {
        let sentence = "this is a long script about habits and mornings that keeps going"
        let script = Array(repeating: sentence.capitalized + ".", count: 80).joined(separator: " ")
        let words = heard(Array(repeating: sentence, count: 80).joined(separator: " "))
        let aligned = CaptionBuilder.aligned(heard: words, script: script)
        #expect(aligned.count == words.count)
        #expect(aligned.filter { $0.text.first?.isUppercase == true }.count == words.count)
    }

    @Test func runsWithSeveralWordsShareTheirTimeAsAnEstimate() {
        let words = CaptionTranscriber.spread("hey there", start: 1, end: 2)
        #expect(words.map(\.text) == ["hey", "there"])
        #expect(words.map(\.start) == [1, 1])
        #expect(words.map(\.end) == [2, 2])
        #expect(words.allSatisfy { $0.isEstimated })
        let single = CaptionTranscriber.spread("hey", start: 1, end: 2)
        #expect(single.first?.isEstimated == false)
    }

    @Test func nothingHeardMakesNoLines() {
        #expect(CaptionBuilder.captions(heard: [], script: "A whole script that was never said.").isEmpty)
    }
}
