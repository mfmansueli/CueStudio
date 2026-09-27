//
//  PlatformPresetTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("PlatformPreset")
struct PlatformPresetTests {
    @Test func tikTokWithMonetizationAimsPastOneMinute() {
        let preset = PlatformPreset.preset(for: .tiktok, monetizationGoals: true)
        #expect(preset.idealRange == 60...90)
        #expect(preset.minimum == 60)
        #expect(preset.goal == .creatorRewards)
    }

    @Test func tikTokWithoutMonetizationHasNoMinimum() {
        let preset = PlatformPreset.preset(for: .tiktok, monetizationGoals: false)
        #expect(preset.idealRange == 15...60)
        #expect(preset.minimum == nil)
        #expect(preset.goal == nil)
    }

    @Test func youTubeIsLandscapeAndPrefersStudio() {
        let preset = PlatformPreset.preset(for: .youtube, monetizationGoals: true)
        #expect(preset.aspect == .landscape)
        #expect(preset.prefersStudio)
        #expect(preset.minimum == 480)
        #expect(preset.goal == .midRollAds)
        #expect(!preset.showsSafeZones)
    }

    @Test func summaryDescribesFrameQualityAndIdealLength() {
        #expect(PlatformPreset.preset(for: .tiktok, monetizationGoals: true).summary == "9:16 · 1080p30 · ideal 1:00–1:30")
    }

    @Test func cameraSettingsTakeFrameResolutionAndFrameRateFromThePreset() {
        var settings = CameraSettings()
        settings.countdown = .ten
        settings.apply(.preset(for: .shorts, monetizationGoals: false))
        #expect(settings.frameRate == .fps60)
        #expect(settings.aspect == .portrait)
        #expect(settings.countdown == .ten)
    }
}
