//
//  NarrationScriptPaceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("NarrationScriptPace")
struct NarrationScriptPaceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Words a second at the prompter's natural speed (1×).
    private var naturalRate: Double { ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed) / 60 }

    @Test func showsTheStartUntilTheRecordingStarts() {
        var pace = NarrationScriptPace()
        #expect(pace.wordsRead(at: now.addingTimeInterval(30)) == 0)
        // A tap before recording does nothing.
        pace.togglePause(at: now)
        #expect(pace.phase == .waiting)
    }

    @Test func readsAtThePrompterPaceFromTheStart() {
        var pace = NarrationScriptPace()
        pace.start(at: now)
        #expect(pace.isReading)
        #expect(abs(pace.wordsRead(at: now.addingTimeInterval(10)) - naturalRate * 10) < 0.0001)
    }

    @Test func aTapHoldsTheTextAndAnotherGoesOnFromThere() {
        var pace = NarrationScriptPace()
        pace.start(at: now)
        pace.togglePause(at: now.addingTimeInterval(4))
        #expect(pace.isPaused)
        let held = pace.wordsRead(at: now.addingTimeInterval(4))
        #expect(pace.wordsRead(at: now.addingTimeInterval(60)) == held)
        pace.togglePause(at: now.addingTimeInterval(60))
        #expect(pace.isReading)
        #expect(abs(pace.wordsRead(at: now.addingTimeInterval(62)) - (held + naturalRate * 2)) < 0.0001)
    }

    @Test func aNewSpeedKeepsWhatWasReadAndGoesOnFaster() {
        var pace = NarrationScriptPace()
        pace.start(at: now)
        let before = pace.wordsRead(at: now.addingTimeInterval(5))
        let faster = ReadTime.naturalSpeed * 2
        pace.setSpeed(faster, at: now.addingTimeInterval(5))
        let rate = ReadTime.wordsPerMinute(speed: pace.speed) / 60
        #expect(rate > naturalRate)
        #expect(abs(pace.wordsRead(at: now.addingTimeInterval(7)) - (before + rate * 2)) < 0.0001)
    }

    @Test func theSpeedStaysInThePrompterRange() {
        var pace = NarrationScriptPace(speed: 99)
        #expect(pace.speed == PrompterSettings.speedRange.upperBound)
        pace.setSpeed(0, at: now)
        #expect(pace.speed == PrompterSettings.speedRange.lowerBound)
    }

    @Test func resetGoesBackToTheStart() {
        var pace = NarrationScriptPace()
        pace.start(at: now)
        pace.reset()
        #expect(pace.phase == .waiting)
        #expect(pace.wordsRead(at: now.addingTimeInterval(10)) == 0)
    }

    @Test func theOffsetIsAWordsShareOfTheTextAndStopsAtTheLastLine() {
        // 100 words over 1,000 points: 10 points a word.
        let offset = NarrationScriptPace.offset(wordsRead: 12, wordCount: 100, contentHeight: 1000, lineHeight: 30, stepsByLine: false)
        #expect(abs(offset - 120) < 0.0001)
        let end = NarrationScriptPace.offset(wordsRead: 500, wordCount: 100, contentHeight: 1000, lineHeight: 30, stepsByLine: false)
        #expect(end == 970)
        #expect(NarrationScriptPace.offset(wordsRead: 5, wordCount: 0, contentHeight: 1000, lineHeight: 30, stepsByLine: false) == 0)
        #expect(NarrationScriptPace.offset(wordsRead: 5, wordCount: 100, contentHeight: 0, lineHeight: 30, stepsByLine: false) == 0)
    }

    @Test func reduceMotionMovesAWholeLineAtATime() {
        let between = NarrationScriptPace.offset(wordsRead: 5.5, wordCount: 100, contentHeight: 1000, lineHeight: 30, stepsByLine: true)
        #expect(between == 30)
        let next = NarrationScriptPace.offset(wordsRead: 6.1, wordCount: 100, contentHeight: 1000, lineHeight: 30, stepsByLine: true)
        #expect(next == 60)
    }

    @Test func theTextIsLargeForThePreviewButNeverPastThePrompterSize() {
        // An iPhone 17's preview area with Voice-over open.
        let editor = NarrationScriptPace.fontSize(forPreview: CGSize(width: 402, height: 300), prompterSize: 36)
        #expect(editor == 24)
        let tall = NarrationScriptPace.fontSize(forPreview: CGSize(width: 430, height: 600), prompterSize: 36)
        #expect(tall == 30)
        let small = NarrationScriptPace.fontSize(forPreview: CGSize(width: 120, height: 210), prompterSize: 36)
        #expect(small == 17)
        let capped = NarrationScriptPace.fontSize(forPreview: CGSize(width: 400, height: 700), prompterSize: 24)
        #expect(capped == 24)
    }
}
