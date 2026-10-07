//
//  RewriteNoticeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the creator is told a tool did is what it did (`RewriteNotice`).
@Suite("Rewrite notice")
struct RewriteNoticeTests {
    private static let range: ClosedRange<TimeInterval> = 60...90

    private static func words(_ count: Int) -> String {
        (0..<count).map { "w\($0)" }.joined(separator: " ")
    }

    private static func notice(_ tool: ScriptTool, before: String, after: String, left: Int = 0, parts: Int = 1) -> RewriteNotice {
        RewriteNotice.after(
            tool, before: before, result: RewriteResult(text: after, parts: parts, leftAsWritten: left), done: "Done it", idealRange: range
        )
    }

    @Test func shorterSaysHowMuchShorter() {
        let notice = Self.notice(.shorterAndDirect, before: Self.words(100), after: Self.words(60))
        #expect(notice.changesScript)
        #expect(notice.message == "Done it · 100 → 60 words")
    }

    @Test func theSameWordsAreNotCalledDone() {
        let before = Self.words(40)
        let notice = Self.notice(.moreHuman, before: before, after: before)
        #expect(!notice.changesScript)
        #expect(notice.message == "Couldn’t write it · Try again")
    }

    @Test func aScriptWithNothingWrongSaysSo() {
        let text = "I tried cold showers for thirty days."
        let notice = Self.notice(.fixGrammar, before: text, after: text)
        #expect(!notice.changesScript)
        #expect(notice.message == "No mistakes to fix")
    }

    @Test func aScriptThatFitsIsNotMoved() {
        let words = ReadTime.words(for: 75)
        let text = Self.words(words)
        let notice = Self.notice(.fitToTime, before: text, after: text, left: 1)
        #expect(!notice.changesScript)
        #expect(notice.message == "Already fits 1:00–1:30")
    }

    @Test func fitToTimeSaysHowFarItGotWhenItDidNotArrive() {
        let notice = Self.notice(.fitToTime, before: Self.words(600), after: Self.words(ReadTime.words(for: 120)))
        #expect(notice.changesScript)
        #expect(notice.message.hasPrefix("Closer to 1:00–1:30 · now "))
    }

    @Test func fitToTimeThatArrivedSaysDone() {
        let notice = Self.notice(.fitToTime, before: Self.words(600), after: Self.words(ReadTime.words(for: 75)))
        #expect(notice.message == "Done it")
    }

    @Test func partsLeftAsWrittenAreSaid() {
        let notice = Self.notice(.fixGrammar, before: Self.words(300), after: Self.words(300) + " ok", left: 2, parts: 9)
        #expect(notice.changesScript)
        #expect(notice.message == "Done it · 2 of 9 parts left as written")
    }

    @Test func nothingDoneAtAllIsNotACelebration() {
        let notice = Self.notice(.moreEnergy, before: Self.words(300), after: Self.words(300) + " ok", left: 9, parts: 9)
        #expect(!notice.changesScript)
    }
}
