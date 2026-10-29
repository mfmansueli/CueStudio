//
//  MusicDuckingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Music lowered under the voice with its own settings (`MusicDuck`): down by the decibels asked, along an S-curve without a
/// corner, staying low through the pauses "Stays low" bridges and coming back in those "Comes back up" doesn't, and a clip saved
/// before the settings sounding exactly as it did.
@Suite("Music ducking")
struct MusicDuckingTests {
    private func volume(at time: TimeInterval, in points: [MusicEnvelope.Point]) -> Double {
        guard let after = points.firstIndex(where: { $0.time >= time }) else { return points.last?.volume ?? 0 }
        guard after > 0 else { return points[0].volume }
        let from = points[after - 1], to = points[after]
        let share = to.time - from.time > 0 ? (time - from.time) / (to.time - from.time) : 1
        return from.volume + (to.volume - from.volume) * share
    }

    private func decibels(_ value: Double) -> Double { 20 * log10(value) }

    @Test func goesDownByTheDecibelsAsked() {
        let speech = [TimeSpan(start: 4, end: 6)]
        for depth in [3.0, 12, 20, 30] {
            let duck = MusicDuck(depth: depth, pauses: .staysLow)
            let points = MusicEnvelope.points(span: TimeSpan(start: 0, end: 12), volume: 0.8, fadeIn: 0, fadeOut: 0, speech: speech, duck: duck)
            let under = volume(at: 5, in: points)
            #expect(abs(decibels(under / 0.8) + depth) < 0.01)
            #expect(abs(volume(at: 1, in: points) - 0.8) < 0.001)
        }
        // Out of range, it stays within 3 to 30 dB.
        #expect(abs(decibels(MusicDuck(depth: 50, pauses: .staysLow).level) + 30) < 0.01)
        #expect(abs(decibels(MusicDuck(depth: 0, pauses: .staysLow).level) + 3) < 0.01)
    }

    @Test func isDownBeforeTheFirstWordAndMovesWithoutACorner() {
        let speech = [TimeSpan(start: 4, end: 6)]
        let timing = MusicEnvelope.Timing.staysLow
        let duck = MusicDuck(depth: 18, pauses: .staysLow)
        let points = MusicEnvelope.points(span: TimeSpan(start: 0, end: 12), volume: 1, fadeIn: 0, fadeOut: 0, speech: speech, duck: duck)
        #expect(abs(volume(at: 4, in: points) - duck.level) < 0.001)
        // Along the way down, every step is smaller near the ends than in the middle (an S, not a line), and it only goes down.
        let down = stride(from: 4 - timing.lead, through: 4, by: timing.lead / 16).map { volume(at: $0, in: points) }
        for (one, next) in zip(down, down.dropFirst()) { #expect(next <= one + 0.000_1) }
        let firstStep = decibels(down[0]) - decibels(down[1])
        let middleStep = decibels(down[7]) - decibels(down[8])
        #expect(firstStep < middleStep / 2)
        // Coming back takes the release, and it's back in full after.
        let back = 6 + timing.hold + timing.release
        #expect(volume(at: 6 + timing.hold / 2, in: points) < duck.level + 0.001)
        #expect(abs(volume(at: back + 0.01, in: points) - 1) < 0.001)
    }

    @Test func staysLowThroughAPauseBetweenSentences() {
        // Three seconds of quiet: "Stays low" keeps it down; "Comes back up" brings it back in between.
        let speech = [TimeSpan(start: 2, end: 4), TimeSpan(start: 7, end: 9)]
        let low = MusicDuck(depth: 12, pauses: .staysLow), back = MusicDuck(depth: 12, pauses: .comesBack)
        #expect(MusicEnvelope.duckSpans(speech, timing: .staysLow) == [TimeSpan(start: 2, end: 9)])
        #expect(MusicEnvelope.duckSpans(speech, timing: .comesBack).count == 2)
        let staying = MusicEnvelope.points(span: TimeSpan(start: 0, end: 12), volume: 1, fadeIn: 0, fadeOut: 0, speech: speech, duck: low)
        let coming = MusicEnvelope.points(span: TimeSpan(start: 0, end: 12), volume: 1, fadeIn: 0, fadeOut: 0, speech: speech, duck: back)
        #expect(abs(volume(at: 5.5, in: staying) - low.level) < 0.001)
        #expect(abs(volume(at: 5.5, in: coming) - 1) < 0.001)
        // A breath between words stays down either way.
        let breath = [TimeSpan(start: 2, end: 4), TimeSpan(start: 4.8, end: 6)]
        #expect(MusicEnvelope.duckSpans(breath, timing: .comesBack).count == 1)
    }

    @Test func aClipSavedBeforeSoundsAsItDid() {
        let speech = [TimeSpan(start: 4, end: 6), TimeSpan(start: 6.2, end: 7)]
        let points = MusicEnvelope.points(span: TimeSpan(start: 0, end: 10), volume: 0.8, fadeIn: 0.5, fadeOut: 0.5, speech: speech)
        // The first way: a quarter, straight ramps of a quarter second, only the moments where something changes.
        #expect(abs(volume(at: 5, in: points) - 0.8 * MusicClip.duckedLevel) < 0.001)
        #expect(points.count <= 8)
        #expect(MusicEnvelope.duckSpans(speech) == [TimeSpan(start: 4, end: 7)])
        #expect(MusicEnvelope.Timing.of(nil) == .legacy)
    }

    @Test func savedSettingsReadBackAndUnknownOnesFallBack() throws {
        let saved = MusicDuck(depth: 20, pauses: .comesBack)
        let data = try JSONEncoder().encode(saved)
        #expect(try JSONDecoder().decode(MusicDuck.self, from: data) == saved)
        let unknown = Data(#"{"depth": 9, "pauses": "somethingNew"}"#.utf8)
        #expect(try JSONDecoder().decode(MusicDuck.self, from: unknown) == MusicDuck(depth: 9, pauses: .staysLow))
        // Music saved before the settings has none.
        var clip = MusicClip(fileName: "a.m4a", title: "Song", fileDuration: 10, start: 0, length: 10)
        clip.duck = .standard
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(clip)) as? [String: Any])
        object["duck"] = nil
        let music = try JSONDecoder().decode(MusicClip.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(music.duck == nil)
    }
}
