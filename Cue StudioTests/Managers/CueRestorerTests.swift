//
//  CueRestorerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A rewrite that dropped the creator's cues gets them back where they were, and its words stay as the model wrote them.
@Suite("Cue restorer")
struct CueRestorerTests {
    /// What the iPhone's model did to a script with eight cues when asked to shorten it (ScriptToolsQualityDeviceTests, 01/11/2026).
    @Test func everyCueTheShortenedScriptDroppedIsBackAfterItsSentence() {
        let before = """
        Do you do 3 mistakes that mess up home workouts? Okay, real talk. I break down 3 common errors you should avoid. [pause]

        Use a spotter when lifting. It keeps your form steady. Forget a cool playlist? Music boosts motivation. [smile] Don’t forget to stretch. \
        Flexibility prevents strain. [look at camera] [pause] [emphasis] Keep your space clear. Safety matters. [pause]

        Save this and share your own tip. [pause] [look at camera]
        """
        let after = """
        Do you make 3 mistakes with home workouts? I break down 3 common errors to avoid.

        Use a spotter when lifting. Music boosts motivation. Stretch. Keep your space clear. Safety matters.

        Save this and share your tip.
        """
        let restored = CueRestorer.restoring(after, from: before)
        #expect(CueParser.count(in: restored) == 8)
        #expect(CueParser.stripCues(restored).split(whereSeparator: \.isWhitespace) == after.split(whereSeparator: \.isWhitespace))
        let paragraphs = restored.components(separatedBy: "\n\n")
        #expect(paragraphs.count == 3)
        #expect(paragraphs[0].hasSuffix("to avoid. [pause]"))
        #expect(paragraphs[1].contains("Music boosts motivation. [smile]"))
        #expect(paragraphs[1].contains("[look at camera] [pause] [emphasis]"))
        #expect(paragraphs[1].hasSuffix("Safety matters. [pause]"))
        #expect(paragraphs[2] == "Save this and share your tip. [pause] [look at camera]")
    }

    @Test func aCueTheRewriteKeptIsNotAddedAgain() {
        let before = "Hello there. [pause] Welcome back. [pause]"
        let after = "Hi there. [pause] Good to see you again."
        let restored = CueRestorer.restoring(after, from: before)
        #expect(CueParser.count(in: restored) == 2)
        #expect(restored == "Hi there. [pause] Good to see you again. [pause]")
    }

    @Test func aCueThatOpenedAParagraphOpensItAgain() {
        let before = "One thing first.\n\n[look at camera] Save this and follow for more."
        let after = "One thing first.\n\nSave it, and follow me."
        #expect(CueRestorer.restoring(after, from: before) == "One thing first.\n\n[look at camera] Save it, and follow me.")
    }

    /// Paragraphs that don't line up: each cue goes to the same point of the script.
    @Test func whenTheParagraphsChangeACueGoesToTheSamePointOfTheScript() {
        let before = "Start here. [pause]\n\nThe middle part goes on a while. [emphasis]\n\nThe end. [smile]"
        let after = "Start here. The middle part goes on a while. The end."
        let restored = CueRestorer.restoring(after, from: before)
        #expect(restored == "Start here. [pause] The middle part goes on a while. [emphasis] The end. [smile]")
    }

    @Test func aRewriteWithEveryCueIsLeftAsItIs() {
        let text = "Hi. [pause]\n\nBye. [smile]"
        #expect(CueRestorer.restoring("Hello! [pause]\n\nSee you. [smile]", from: text) == "Hello! [pause]\n\nSee you. [smile]")
        #expect(CueRestorer.restoring("Hello!\n\nSee you.", from: "Hi.\n\nBye.") == "Hello!\n\nSee you.")
        #expect(CueRestorer.restoring("", from: text).isEmpty)
    }
}
