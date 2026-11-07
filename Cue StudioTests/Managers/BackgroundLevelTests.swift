//
//  BackgroundLevelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The three numbers Clean Up measures a recording by (D16): its background, how much that moves, and its voice.
@Suite("Background level")
struct BackgroundLevelTests {
    @Test func aFanUnderAVoiceIsItsFloorAndTheVoiceItsSpeech() throws {
        // 30 % fan at −35 (moving between −35 and −34), 70 % voice at −15.
        let fan = (0..<30).map { Float($0.isMultiple(of: 2) ? -35 : -34) }
        let level = try #require(BackgroundLevel.measure(fan + Array(repeating: -15, count: 70)))
        #expect(level.floor == -35 || level.floor == -34)
        #expect(level.spread >= 0 && level.spread <= 1)
        #expect(level.speech == -15)
        #expect(level.lowest == -35)
    }

    @Test func digitalSilenceDoesntCount() throws {
        let levels = Array(repeating: Float(-160), count: 50) + Array(repeating: -60, count: 20) + Array(repeating: -20, count: 30)
        let level = try #require(BackgroundLevel.measure(levels))
        #expect(level.floor == -60)
    }

    @Test func tooLittleSoundIsntMeasured() {
        #expect(BackgroundLevel.measure(Array(repeating: -20, count: BackgroundLevel.minimumReadings - 1)) == nil)
        #expect(BackgroundLevel.measure(Array(repeating: -160, count: 200)) == nil)
    }
}
