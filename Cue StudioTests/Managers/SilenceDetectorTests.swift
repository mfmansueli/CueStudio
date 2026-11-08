//
//  SilenceDetectorTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("SilenceDetector")
struct SilenceDetectorTests {
    private func levels(_ pattern: [(Float, Int)]) -> [Float] {
        pattern.flatMap { Array(repeating: $0.0, count: $0.1) }
    }

    @Test func longPausesBecomePaddedSilences() {
        // 1 s of speech, 1 s of quiet, 1 s of speech, at 0.1 s per reading.
        let silences = SilenceDetector.silences(levels: levels([(-20, 10), (-60, 10), (-20, 10)]), interval: 0.1)
        #expect(silences.count == 1)
        // A breath of 0.12 s stays on each side.
        #expect(abs(silences[0].start - 1.12) < 0.001)
        #expect(abs(silences[0].end - 1.88) < 0.001)
    }

    @Test func breathsBetweenWordsAreNeverSuggested() {
        #expect(SilenceDetector.silences(levels: levels([(-20, 10), (-60, 2), (-20, 10)]), interval: 0.1).isEmpty)
    }

    @Test func shortPausesAreFoundForTheThreshold() {
        // Half a second: under the default "Ignore pauses under 0.7s", but found.
        let silences = SilenceDetector.silences(levels: levels([(-20, 10), (-60, 5), (-20, 10)]), interval: 0.1)
        #expect(silences.count == 1)
        #expect(abs(SilenceDetector.silenceLength(ofCut: silences[0]) - 0.5) < 0.001)
    }

    @Test func trailingSilenceCounts() {
        let silences = SilenceDetector.silences(levels: levels([(-20, 5), (-80, 20)]), interval: 0.1)
        #expect(silences.count == 1)
        #expect(abs(silences[0].duration - 1.76) < 0.001)
    }

    // MARK: - A level that follows the background (D16)

    /// A take of `pattern` at 0.05 s per reading, every other reading `wobble` dB louder (a background's own movement).
    private func take(_ pattern: [(Float, Int)], wobble: Float = 0) -> [Float] {
        levels(pattern).enumerated().map { $0.element + ($0.offset.isMultiple(of: 2) ? 0 : wobble) }
    }

    @Test func aQuietRoomHearsItsPausesAsBefore() {
        let levels = take([(-15, 40), (-60, 20), (-15, 40), (-60, 8), (-15, 40)])
        let detection = SilenceDetector.pauses(levels: levels, interval: 0.05)
        #expect(detection.hearing == .clear)
        #expect(detection.pauses.map(\.cut) == SilenceDetector.silences(levels: levels, interval: 0.05))
        #expect(detection.pauses.allSatisfy { $0.isClear })
    }

    @Test func aFanRaisesTheLevelAndItsPausesWaitForAListen() throws {
        // Speech at −15 dBFS over a fan at −35 (moving 1 dB): the fixed level hears nothing.
        let levels = take([(-15, 60), (-35, 30), (-15, 60), (-35, 30), (-15, 60)], wobble: 1)
        #expect(SilenceDetector.silences(levels: levels, interval: 0.05).isEmpty)
        let detection = SilenceDetector.pauses(levels: levels, interval: 0.05)
        #expect(detection.hearing == .overBackgroundSound)
        #expect(detection.pauses.count == 2)
        let first = try #require(detection.pauses.first)
        #expect(!first.isClear)
        #expect(abs(first.silence.start - 3) < 0.001 && abs(first.silence.end - 4.5) < 0.001)
        // A wider breath on each side than in a quiet room.
        #expect(abs(first.cut.start - (3 + SilenceDetector.uncertainPadding)) < 0.001)
        #expect(abs(first.cut.end - (4.5 - SilenceDetector.uncertainPadding)) < 0.001)
    }

    @Test func aWordFadingIntoTheBackgroundKeepsItsEnd() throws {
        // The word's last sound fades through −30 and −32.8 into a fan at −35: the pause starts where it settles, not where it
        // crosses the level (−32.5).
        let levels = take([(-15, 60), (-30, 2), (-32.8, 2), (-35, 30), (-15, 60), (-35, 30), (-15, 60)])
        let first = try #require(SilenceDetector.pauses(levels: levels, interval: 0.05).pauses.first)
        #expect(abs(first.silence.start - 3.2) < 0.001)
    }

    @Test func aSoftStretchAtTheBackgroundsLevelIsLetPass() throws {
        // After a pause, a soft stretch speaks just under the moved level, around a pause of its own: the words around that one
        // are no louder than the fan, so it isn't suggested.
        let levels = take([(-12, 300), (-35, 60), (-12, 100), (-33, 60), (-35, 20), (-33, 60), (-12, 100)])
        let detection = SilenceDetector.pauses(levels: levels, interval: 0.05)
        #expect(detection.hearing == .overBackgroundSound)
        #expect(detection.pauses.count == 1)
        let only = try #require(detection.pauses.first)
        #expect(abs(only.silence.start - 15) < 0.001 && abs(only.silence.end - 18) < 0.001)
    }

    @Test func aVoiceThatDoesntStandClearOfTheBackgroundIsInconclusive() {
        // A fan only 8 dB under the voice.
        let levels = take([(-20, 60), (-28, 30), (-20, 60), (-28, 30), (-20, 60)], wobble: 1)
        let detection = SilenceDetector.pauses(levels: levels, interval: 0.05)
        #expect(detection.hearing == .tooMuchBackgroundSound)
        #expect(detection.hearing.isInconclusive)
        #expect(detection.pauses.isEmpty)
    }

    @Test func aBackgroundWithNoPauseUnderItIsInconclusive() {
        // Music never quiet for long enough: "no pauses" can't be told from "can't hear them".
        let music = levels(Array(repeating: [(-14, 10), (-31, 4)], count: 5).flatMap { $0 })
        #expect(SilenceDetector.pauses(levels: music, interval: 0.05).hearing == .tooMuchBackgroundSound)
    }

    @Test func aSoftVoiceInAQuietRoomMovesTheLevelUnderIt() throws {
        // A voice at −33 dBFS: the fixed −42 would take its quiet words (−44) for a pause.
        let levels = take([(-33, 40), (-44, 8), (-33, 40), (-65, 20), (-33, 40)])
        #expect(SilenceDetector.silences(levels: levels, interval: 0.05).count == 2)
        let detection = SilenceDetector.pauses(levels: levels, interval: 0.05)
        #expect(detection.hearing == .softVoice)
        #expect(detection.pauses.count == 1)
        let only = try #require(detection.pauses.first)
        #expect(!only.isClear)
        #expect(abs(only.silence.start - 4.4) < 0.001)
    }

    @Test func digitalSilenceBeforeTheMicrophoneStartsIsntTheBackground() {
        let levels = take([(-120, 10), (-15, 40), (-60, 20), (-15, 40)])
        #expect(SilenceDetector.pauses(levels: levels, interval: 0.05).hearing == .clear)
    }

    @Test func aPauseHeardOverBackgroundGoesByTheSilenceItWasHeardAs() {
        let heard = CleanUpSuggestion(
            kind: .pause, span: TimeSpan(start: 3.25, end: 4.25), confidence: 0.5, hearing: .overBackgroundSound,
            silence: TimeSpan(start: 3, end: 4.5)
        )
        #expect(abs(SilenceDetector.silenceLength(of: heard) - 1.5) < 0.001)
        let clear = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 1, end: 2), confidence: 0.95)
        #expect(abs(SilenceDetector.silenceLength(of: clear) - 1.24) < 0.001)
    }
}
