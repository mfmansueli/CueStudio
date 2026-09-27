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

    @Test func cameraSettingsTakeFrameResolutionAndFrameRateFromThePreset() {
        var settings = CameraSettings()
        settings.countdown = .ten
        settings.apply(TestData.preset(.shorts, monetizationGoals: false))
        #expect(settings.frameRate == .fps60)
        #expect(settings.aspect == .portrait)
        #expect(settings.countdown == .ten)
    }
}
