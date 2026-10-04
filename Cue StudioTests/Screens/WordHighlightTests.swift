//
//  WordHighlightTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

/// Voice following lights the words as they are said: where they sit in the drawn text, and which are lit.
@Suite("Word highlight")
struct WordHighlightTests {
    @Test func eachWordKnowsWhereItIsDrawn() {
        let spans = WordSpans.spans(in: "Three tiny habits", showsCues: true, language: nil)
        #expect(spans.map(\.characters) == [0..<5, 6..<10, 11..<17])
        #expect(spans.allSatisfy { $0.tokens == 1 })
    }

    @Test func aCueTagTakesItsPlaceInTheDrawnText() {
        // "Hello [pause] there" is drawn as "Hello " + " PAUSE " + " there".
        let shown = WordSpans.spans(in: "Hello [pause] there", showsCues: true, language: nil)
        #expect(shown.count == 2)
        #expect(shown[0].characters == 0..<5)
        #expect(shown[1].characters.lowerBound == 6 + 7 + 1)
        let hidden = WordSpans.spans(in: "Hello [pause] there", showsCues: false, language: nil)
        #expect(hidden.map(\.characters) == [0..<5, 6..<11])
    }

    @Test func anApostropheStaysInsideItsWord() {
        let spans = WordSpans.spans(in: "Don’t stop", showsCues: false, language: nil)
        #expect(spans.map(\.characters) == [0..<5, 6..<10])
    }

    @Test func theSpansAddUpToTheScriptsTokens() {
        let text = "Okay, real talk. [pause]\n\nStart small, one tiny step.\n\nTry it tomorrow."
        let words = ScriptWords(text: text)
        let paragraphs = CueParser.paragraphs(in: text)
        let counted = paragraphs.map { WordSpans.spans(in: $0, showsCues: true, language: nil).map(\.tokens).reduce(0, +) }
        #expect(counted == [3, 5, 3])
        #expect(words.paragraphStarts == [0, 3, 8, 11])
    }

    // MARK: - Which words are lit

    private func highlight(position: Int) -> WordHighlight {
        let text = "One two three four five six seven eight nine ten.\n\nEleven twelve."
        let paragraphs = CueParser.paragraphs(in: text)
        return WordHighlight(
            position: position,
            spans: paragraphs.map { WordSpans.spans(in: $0, showsCues: true, language: nil) },
            starts: ScriptWords(text: text).paragraphStarts
        )
    }

    @Test func nothingIsLitBeforeTheFirstWordIsHeard() {
        let start = highlight(position: 0)
        #expect(start.lit(in: 0) == nil && start.lit(in: 1) == nil)
    }

    @Test func theWordsJustSaidAreLitAndTheNewestStandsOut() throws {
        let lit = try #require(highlight(position: 3).lit(in: 0))
        #expect(lit.words == 0..<3 && lit.newest == 2)
    }

    @Test func onlyAboutALineStaysLit() throws {
        let lit = try #require(highlight(position: 10).lit(in: 0))
        #expect(lit.words == 3..<10 && lit.newest == 9)
        #expect(lit.words.count == WordHighlight.litWords)
    }

    @Test func theParagraphBeingReadIsTheOneThatHoldsTheLastWordSaid() throws {
        #expect(highlight(position: 10).currentParagraph == 0)
        #expect(highlight(position: 11).currentParagraph == 1)
        let second = try #require(highlight(position: 11).lit(in: 1))
        #expect(second.words == 0..<1 && second.newest == 0)
        #expect(highlight(position: 11).lit(in: 0) == nil, "the earlier paragraph rests")
    }

    @MainActor
    @Test func theHighlighterLightsNothingUnlessRecognitionFollows() {
        let text = "One two three.\n\nFour five."
        let highlighter = PrompterHighlighter()
        highlighter.words = ScriptWords(text: text)
        let paragraphs = CueParser.paragraphs(in: text)
        #expect(highlighter.highlight(paragraphs: paragraphs, showsCues: true, language: nil) == nil)
        highlighter.isActive = true
        highlighter.position = 2
        let on = highlighter.highlight(paragraphs: paragraphs, showsCues: true, language: nil)
        #expect(on?.position == 2 && on?.spans.count == 2)
        #expect(highlighter.highlight(paragraphs: ["different"], showsCues: true, language: nil) == nil, "another text than the words")
    }

    @MainActor
    @Test func theStyledTextRestsAt42PercentAndLightsTheSaidWords() {
        let spans = WordSpans.spans(in: "One two three", showsCues: false, language: nil)
        let styled = HighlightedParagraph.styled(
            AttributedString("One two three"), spans: spans, lit: (0..<2, 1), color: .white, accent: .yellow
        )
        let colors = styled.runs.map { $0.foregroundColor }
        #expect(colors.first == Color.white)
        #expect(colors.last == Color.white.opacity(HighlightedParagraph.restingOpacity))
        #expect(colors.contains(Color.yellow), "the newest word")
    }
}
