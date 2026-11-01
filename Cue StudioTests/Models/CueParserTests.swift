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

    /// A "[" left open never takes the paragraphs after it, up to some later "]", out of the words read and counted.
    @Test func aBracketLeftOpenDoesNotSwallowTheNextParagraphs() {
        let text = "I tried it [look at\n\nThe second paragraph has words.\n\nThe third one [smile] too."
        #expect(CueParser.count(in: text) == 1)
        #expect(CueParser.stripCues(text).contains("The second paragraph has words."))
        #expect(ReadTime.wordCount(in: text) == 14)
    }

    @Test func paragraphsAreTrimmedAndNonEmpty() {
        #expect(CueParser.paragraphs(in: "One\n\n  Two  \n\n\nThree") == ["One", "Two", "Three"])
    }
}
