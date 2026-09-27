//
//  CueParserTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("CueParser")
struct CueParserTests {
    @Test func splitsSpeechAndCues() {
        let segments = CueParser.segments(in: "Okay [pause] go")
        #expect(segments == [
            CueSegment(kind: .speech, text: "Okay "),
            CueSegment(kind: .cue, text: "pause"),
            CueSegment(kind: .speech, text: " go"),
        ])
    }

    @Test func emptyCuesAreDropped() {
        #expect(CueParser.segments(in: "Hi [] there").allSatisfy { $0.kind == .speech })
    }

    @Test func stripCuesCollapsesSpaces() {
        #expect(CueParser.stripCues("Okay [pause] go [smile]") == "Okay go")
    }

    @Test func paragraphsAreTrimmedAndNonEmpty() {
        #expect(CueParser.paragraphs(in: "One\n\n  Two  \n\n\nThree") == ["One", "Two", "Three"])
    }
}
