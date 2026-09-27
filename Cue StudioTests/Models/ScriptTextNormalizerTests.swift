//
//  ScriptTextNormalizerTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptTextNormalizer")
struct ScriptTextNormalizerTests {
    @Test func everyLineBecomesAParagraph() {
        #expect(ScriptTextNormalizer.normalize("Line one\r\nLine two\n\n\nPara") == "Line one\n\nLine two\n\nPara")
    }

    @Test func wrappedLinesJoinForDocuments() {
        #expect(ScriptTextNormalizer.normalize("Line one\nLine two\n\nPara", joinWrappedLines: true) == "Line one Line two\n\nPara")
    }

    @Test func spacesAreCollapsed() {
        #expect(ScriptTextNormalizer.normalize("Too   many\t spaces") == "Too many spaces")
    }

    @Test func fountainNotesAndCommentsAreRemoved() {
        let text = "INT. KITCHEN\n\nHello [[note to self]] there. /* cut this */"
        #expect(ScriptTextNormalizer.normalizeFountain(text) == "INT. KITCHEN\n\nHello there.")
    }

    @Test func titleComesFromTheFileName() {
        #expect(ScriptTextNormalizer.suggestedTitle(fileName: "Episode 13 outline.pdf", text: "x") == "Episode 13 outline")
    }

    @Test func titleFallsBackToTheFirstWords() {
        let title = ScriptTextNormalizer.suggestedTitle(fileName: nil, text: "Hey, it's me again! [smile] Today I'm answering questions")
        #expect(title == "Hey, it's me again! Today I'm")
    }
}
