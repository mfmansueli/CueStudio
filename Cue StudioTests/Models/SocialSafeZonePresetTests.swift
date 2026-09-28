//
//  SocialSafeZonePresetTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("SocialSafeZonePreset")
struct SocialSafeZonePresetTests {
    private func zone(top: Double = 220, bottom: Double = 420, left: Double = 60, right: Double = 120) -> SocialSafeZonePreset {
        SocialSafeZonePreset(aspect: .portrait, videoWidth: 1080, videoHeight: 1920, top: top, bottom: bottom, left: left, right: right)
    }

    @Test func recommendedContentIsTheFrameMinusTheMargins() {
        #expect(zone().recommendedContentRect == CGRect(x: 60, y: 220, width: 900, height: 1280))
        #expect(zone().videoSize == CGSize(width: 1080, height: 1920))
    }

    @Test func marginsMustLeaveSomethingClear() {
        #expect(zone().isValid)
        #expect(!zone(top: 1000, bottom: 1000).isValid)
        #expect(!zone(left: -10).isValid)
    }
}
