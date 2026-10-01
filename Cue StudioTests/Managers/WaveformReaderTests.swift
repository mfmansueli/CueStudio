//
//  WaveformReaderTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("WaveformReader")
struct WaveformReaderTests {
    @Test func levelsAreOnADecibelScale() {
        #expect(WaveformReader.level(fromRMS: 0) == WaveformReader.floor)
        #expect(WaveformReader.level(fromRMS: 1) == 1)
        // −28 dBFS is half way between −50 and −6.
        let half = WaveformReader.level(fromRMS: pow(10, -28 / 20))
        #expect(abs(half - 0.5) < 0.001)
        #expect(WaveformReader.level(fromRMS: 0.000_01) == WaveformReader.floor)
    }

    @Test func oneReadingPerWindow() {
        let samples = ArraySlice([Float](repeating: 0.5, count: 2_000))
        let levels = WaveformReader.readings(samples, window: 800)
        #expect(levels.count == 3)
        #expect(levels.allSatisfy { abs($0 - levels[0]) < 0.000_1 })
    }

    @Test func aRecordingIsReadEveryTenthOfASecondAndLoudPartsStandOut() async throws {
        let url = try await TestClip.make(seconds: 4, loudSeconds: [1, 2])
        defer { try? FileManager.default.removeItem(at: url) }
        let levels = try await WaveformReader.levels(ofVideoAt: url)
        #expect(abs(levels.count - 40) <= 1)
        let quiet = levels[2..<8].reduce(0, +) / 6
        let loud = levels[12..<28].reduce(0, +) / 16
        #expect(loud > quiet + 0.3)
    }
}
