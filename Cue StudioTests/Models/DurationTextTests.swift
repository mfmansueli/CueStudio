//
//  DurationTextTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("DurationText")
struct DurationTextTests {
    @Test func shortUsesSecondsUnderAMinute() {
        #expect(DurationText.short(44.4) == "44s")
        #expect(DurationText.short(0) == "1s")
    }

    @Test func shortUsesClockFromAMinute() {
        #expect(DurationText.short(65) == "1:05")
    }

    @Test func clockPadsSeconds() {
        #expect(DurationText.clock(480) == "8:00")
        #expect(DurationText.clock(61) == "1:01")
    }

    @Test func remainingRoundsUp() {
        #expect(DurationText.remaining(12.2) == "13s")
        #expect(DurationText.remaining(59.5) == "1:00")
    }

    @Test func recordingClockHasTwoDigitMinutes() {
        #expect(DurationText.recording(62) == "01:02")
        #expect(DurationText.recording(0) == "00:00")
    }
}
