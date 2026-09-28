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

    @Test func timecodeShowsHundredthsUnderAMinute() {
        #expect(DurationText.timecode(4.32, total: 11) == "00:04.32")
        #expect(DurationText.timecode(11, total: 11) == "00:11.00")
        #expect(DurationText.timecode(0, total: 9.4) == "00:00.00")
    }

    @Test func timecodeShowsHoursFromAMinute() {
        #expect(DurationText.timecode(64, total: 64) == "00:01:04")
        #expect(DurationText.timecode(6.18, total: 64) == "00:00:06")
        #expect(DurationText.timecode(3_725, total: 4_000) == "01:02:05")
    }

    @Test func timecodeNeverShowsNonsense() {
        #expect(DurationText.timecode(-2, total: 11) == "00:00.00")
        #expect(DurationText.timecode(.nan, total: 11) == "00:00.00")
    }
}
