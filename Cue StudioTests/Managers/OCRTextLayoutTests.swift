//
//  OCRTextLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("OCRTextLayout")
struct OCRTextLayoutTests {
    private func line(_ text: String, y: Double, x: Double = 0.1) -> RecognizedLine {
        RecognizedLine(text: text, box: CGRect(x: x, y: y, width: 0.8, height: 0.02))
    }

    @Test func wrappedLinesJoinAndGapsStartParagraphs() {
        let lines = [
            line("Mornings are better", y: 0.10),
            line("with Oat & Co.", y: 0.125),
            line("Use code MORNING.", y: 0.20),
        ]
        #expect(OCRTextLayout.text(from: lines) == "Mornings are better with Oat & Co.\n\nUse code MORNING.")
    }

    @Test func linesAreReadTopToBottomWhateverTheOrder() {
        let lines = [line("second", y: 0.30), line("first", y: 0.10)]
        #expect(OCRTextLayout.text(from: lines) == "first\n\nsecond")
    }

    @Test func hyphenatedWordsAreRejoined() {
        let lines = [line("the tele-", y: 0.10), line("prompter", y: 0.125)]
        #expect(OCRTextLayout.text(from: lines) == "the teleprompter")
    }

    @Test func noLinesNoText() {
        #expect(OCRTextLayout.text(from: []).isEmpty)
    }
}
