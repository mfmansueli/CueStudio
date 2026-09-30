//
//  MusicEnvelopeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// How loud music is over time: its volume and fades, and, when it ducks, lower while someone
/// speaks, going down a moment before the voice and back a moment after, without pumping between
/// close stretches.
@Suite("Music envelope")
struct MusicEnvelopeTests {
    private func volume(at time: TimeInterval, in points: [MusicEnvelope.Point]) -> Double {
        guard let after = points.firstIndex(where: { $0.time >= time }) else { return points.last?.volume ?? 0 }
        guard after > 0 else { return points[0].volume }
        let from = points[after - 1], to = points[after]
        let share = to.time - from.time > 0 ? (time - from.time) / (to.time - from.time) : 1
        return from.volume + (to.volume - from.volume) * share
    }

    @Test func fadesInAndOutAtItsVolume() {
        let points = MusicEnvelope.points(span: TimeSpan(start: 2, end: 12), volume: 0.5, fadeIn: 1, fadeOut: 2, speech: nil)
        #expect(points.first == MusicEnvelope.Point(time: 2, volume: 0))
        #expect(abs(volume(at: 3, in: points) - 0.5) < 0.001)
        #expect(abs(volume(at: 7, in: points) - 0.5) < 0.001)
        #expect(abs(volume(at: 11, in: points) - 0.25) < 0.001)
        #expect(points.last == MusicEnvelope.Point(time: 12, volume: 0))
    }

    @Test func fadesLongerThanTheClipShareIt() {
        let points = MusicEnvelope.points(span: TimeSpan(start: 0, end: 2), volume: 1, fadeIn: 3, fadeOut: 1, speech: nil)
        // 3 : 1 of two seconds: in for 1.5 s, out for 0.5 s.
        #expect(abs(volume(at: 1.5, in: points) - 1) < 0.001)
        #expect(volume(at: 0.75, in: points) < 0.6)
    }

    @Test func goesDownBeforeTheVoiceAndBackAfterIt() {
        let speech = [TimeSpan(start: 4, end: 6)]
        let points = MusicEnvelope.points(span: TimeSpan(start: 0, end: 10), volume: 0.8, fadeIn: 0, fadeOut: 0, speech: speech)
        let low = 0.8 * MusicClip.duckedLevel
        #expect(abs(volume(at: 2, in: points) - 0.8) < 0.001)
        // Already down when the first word starts, and until a moment after the last.
        #expect(abs(volume(at: 4, in: points) - low) < 0.001)
        #expect(abs(volume(at: 6 + MusicEnvelope.hold, in: points) - low) < 0.001)
        #expect(volume(at: 4 - MusicClip.duckRamp / 2, in: points) > low)
        #expect(abs(volume(at: 7, in: points) - 0.8) < 0.001)
    }

    @Test func staysDownBetweenCloseStretchesOfSpeech() {
        let speech = [TimeSpan(start: 2, end: 3), TimeSpan(start: 3.6, end: 5)]
        let ducks = MusicEnvelope.duckSpans(speech)
        #expect(ducks == [TimeSpan(start: 2, end: 5)])
        // Far apart, it comes back in between.
        #expect(MusicEnvelope.duckSpans([TimeSpan(start: 2, end: 3), TimeSpan(start: 6, end: 7)]).count == 2)
    }

    @Test func withoutDuckingSpeechChangesNothing() {
        let points = MusicEnvelope.points(span: TimeSpan(start: 0, end: 10), volume: 0.6, fadeIn: 0, fadeOut: 0, speech: nil)
        #expect(points.allSatisfy { abs($0.volume - 0.6) < 0.001 })
    }
}
