//
//  PlatformPresetTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("PlatformPreset")
struct PlatformPresetTests {
    @Test func summaryDescribesFrameQualitySafeZonesAndIdealLength() {
        #expect(TestData.preset(.tiktok).summary == "9:16 · 1080p30 · safe zones · ideal 1:00–1:30")
    }

    @Test func summaryLeavesOutSafeZonesWhenThePlatformHasNone() {
        #expect(TestData.preset(.youtube).summary == "16:9 · 4K24 · ideal 8:00–15:00")
    }

    @Test func theRecommendationTakesFrameResolutionAndFrameRateFromThePreset() {
        var camera = CameraSettings()
        camera.countdown = .ten
        let recommendation = SetupRecommendation(platform: .shorts, preset: TestData.preset(.shorts, monetizationGoals: false))
        let recommended = recommendation.applied(to: CreatorSetup(camera: camera)).applied(to: camera)
        #expect(recommended.frameRate == .fps60)
        #expect(recommended.aspect == .portrait)
        #expect(recommended.countdown == .ten)
    }
}
