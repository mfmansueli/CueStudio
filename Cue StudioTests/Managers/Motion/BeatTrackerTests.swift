//
//  BeatTrackerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Beats found in click tracks of known tempo, with a soft noise floor and a quiet start: the tempo, every beat within a few
/// milliseconds, none in the silence.
@Suite("BeatTracker")
struct BeatTrackerTests {
    /// `seconds` of clicks every 60/`tempo` seconds from `start` (a short decaying tone), over noise.
    static func clicks(tempo: Double, seconds: Double, start: Double = 0, accent: Bool = false) -> [Float] {
        let rate = BeatTracker.sampleRate
        var samples = [Float](repeating: 0, count: Int(seconds * rate))
        var generator = SystemRandomNumberGenerator()
        for index in samples.indices { samples[index] = Float.random(in: -0.01...0.01, using: &generator) }
        let period = 60 / tempo
        var beat = 0
        var time = start
        while time < seconds - 0.1 {
            let first = Int(time * rate)
            let loud: Float = accent && beat % 4 == 0 ? 0.9 : 0.6
            for offset in 0..<Int(0.05 * rate) where first + offset < samples.count {
                let t = Double(offset) / rate
                samples[first + offset] += loud * Float(sin(2 * .pi * 1_200 * t) * exp(-t * 60))
            }
            beat += 1
            time += period
        }
        return samples
    }

    @Test(arguments: [90.0, 120, 128, 150])
    func findsTheTempoAndEveryBeat(tempo: Double) throws {
        let result = try #require(BeatTracker.beats(in: Self.clicks(tempo: tempo, seconds: 20, accent: true)))
        #expect(abs(result.tempo - tempo) < 3, "tempo \(result.tempo)")
        let period = 60 / tempo
        // Every beat after the first two seconds, within 25 ms of a click.
        for beat in result.beats where beat > 2 && beat < 18 {
            let nearest = (beat / period).rounded() * period
            #expect(abs(beat - nearest) < 0.025, "beat at \(beat) s, click at \(nearest) s")
        }
        #expect(result.beats.count >= Int(16 / period))
    }

    @Test func noBeatsInTheSilenceBeforeTheMusic() throws {
        let result = try #require(BeatTracker.beats(in: Self.clicks(tempo: 120, seconds: 16, start: 5)))
        #expect((result.beats.first ?? 0) > 4.5, "first beat at \(result.beats.first ?? 0) s")
    }

    @Test func aSteadyNoiseHasNoPulse() {
        var generator = SystemRandomNumberGenerator()
        let noise = (0..<Int(10 * BeatTracker.sampleRate)).map { _ in Float.random(in: -0.2...0.2, using: &generator) }
        let result = BeatTracker.beats(in: noise)
        #expect(result == nil || (result?.beats.count ?? 0) < 12)
    }
}
