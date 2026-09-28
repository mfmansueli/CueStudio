//
//  SafeZoneChoiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("SafeZoneChoice")
struct SafeZoneChoiceTests {
    private let rules = TestData.rules

    private func resolve(_ aspect: AspectRatio, script: Platform? = nil, pick: SafeZoneChoice? = nil) -> SafeZoneChoice? {
        SafeZoneChoice.resolve(pick: pick, scriptPlatform: script, aspect: aspect, rules: rules)
    }

    @Test func chipsFitTheFrame() {
        #expect(SafeZoneChoice.options(for: .portrait, rules: rules) == [.platform(.reels), .platform(.tiktok), .platform(.shorts), .platform(.stories), .custom])
        #expect(SafeZoneChoice.options(for: .vertical, rules: rules) == [.platform(.linkedin), .custom])
        #expect(SafeZoneChoice.options(for: .square, rules: rules) == [.custom])
        #expect(SafeZoneChoice.options(for: .landscape, rules: rules).isEmpty)
    }

    @Test func theScriptsPlatformComesFirst() {
        #expect(resolve(.portrait, script: .tiktok) == .platform(.tiktok))
        #expect(resolve(.vertical, script: .linkedin) == .platform(.linkedin))
    }

    @Test func withoutAScriptVerticalVideoShowsReels() {
        #expect(resolve(.portrait) == .platform(.reels))
    }

    @Test func aPlatformWithoutAZoneForTheFrameFallsBack() {
        #expect(resolve(.portrait, script: .youtube) == .platform(.reels))
        #expect(resolve(.vertical, script: .tiktok) == .platform(.linkedin))
        #expect(resolve(.square, script: .reels) == .custom)
    }

    @Test func horizontalVideoNeedsNone() {
        #expect(resolve(.landscape, script: .youtube) == nil)
        #expect(resolve(.landscape, pick: .custom) == nil)
    }

    @Test func thePickWinsWhileItFitsTheFrame() {
        #expect(resolve(.portrait, script: .tiktok, pick: .platform(.shorts)) == .platform(.shorts))
        #expect(resolve(.portrait, script: .tiktok, pick: .custom) == .custom)
        #expect(resolve(.vertical, script: .linkedin, pick: .platform(.shorts)) == .platform(.linkedin))
    }

    @Test func labels() {
        #expect(SafeZoneChoice.platform(.reels).overlayLabel == "INSTAGRAM REELS SAFE AREA")
        #expect(SafeZoneChoice.custom.overlayLabel == "CUSTOM SAFE AREA")
        #expect(SafeZoneChoice.platform(.tiktok).label == "TikTok")
    }
}
