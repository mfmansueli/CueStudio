//
//  CommentParserTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Cue takes from a screenshot of a comment: the @name and the words, without the app's own buttons.
@Suite("CommentParser")
struct CommentParserTests {
    @Test func theHandleAndTheCommentAreSeparated() {
        let parsed = CommentParser.parse("@maya.costa\nDo you ever skip the morning routine?\n2h\nReply")
        #expect(parsed.author == "@maya.costa")
        #expect(parsed.text == "Do you ever skip the morning routine?")
    }

    @Test func aHandleWithTheCommentOnTheSameLine() {
        let parsed = CommentParser.parse("@leo_p How do you stay consistent on weekends?")
        #expect(parsed.author == "@leo_p")
        #expect(parsed.text == "How do you stay consistent on weekends?")
    }

    @Test func theAppsOwnButtonsTimesAndCountsAreLeftOut() {
        let parsed = CommentParser.parse("@ana\nWhat mic is that?\n3d\n12 likes\nReply\nView replies\n1.2K")
        #expect(parsed.text == "What mic is that?")
    }

    @Test func aCommentWithoutAHandleIsJustTheWords() {
        let parsed = CommentParser.parse("Where did you get that jacket?")
        #expect(parsed.author == nil)
        #expect(parsed.text == "Where did you get that jacket?")
    }

    @Test func aLongCommentOnSeveralLinesJoinsIntoOne() {
        let parsed = CommentParser.parse("@sam\nI tried your cold shower tip\nand honestly it worked\nthanks!")
        #expect(parsed.text == "I tried your cold shower tip and honestly it worked thanks!")
    }

    @Test func nothingReadableGivesNothing() {
        #expect(CommentParser.parse("Reply\n2h").text.isEmpty)
    }

    @Test func theCardSaysWhoAndWhat() {
        #expect(ScriptComment(author: "@maya", text: "Why?").cardText == "@maya · Why?")
        #expect(ScriptComment(author: nil, text: "Why?").cardText == "Why?")
    }
}
