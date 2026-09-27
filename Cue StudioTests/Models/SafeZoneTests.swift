//
//  SafeZoneTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("SafeZone")
struct SafeZoneTests {
    private let reference = CGSize(width: 402, height: 874)

    @Test func rightAlignedColumnHugsTheRightEdge() {
        let zone = SafeZone(kind: .buttons, right: 8, top: 386, width: 56, height: 242)
        #expect(zone.frame(in: reference, reference: reference) == CGRect(x: 338, y: 386, width: 56, height: 242))
    }

    @Test func spanningZoneFillsBetweenItsMargins() {
        let zone = SafeZone(kind: .caption, left: 12, right: 74, top: 556, height: 70)
        #expect(zone.frame(in: reference, reference: reference) == CGRect(x: 12, y: 556, width: 316, height: 70))
    }

    @Test func zonesScaleWithTheScreen() {
        let zone = SafeZone(kind: .caption, left: 12, right: 12, top: 437, height: 64)
        let frame = zone.frame(in: CGSize(width: 804, height: 1748), reference: reference)
        #expect(frame == CGRect(x: 24, y: 874, width: 756, height: 128))
    }

    @Test func labelsNameThePlatformUI() {
        #expect(SafeZone(kind: .buttons, top: 0, height: 1).label(platformName: "TikTok") == "TIKTOK BUTTONS")
        #expect(SafeZone(kind: .replyBar, top: 0, height: 1).label(platformName: "Stories") == "REPLY BAR · STORIES UI")
    }

    @Test func onlyButtonColumnsAreVertical() {
        #expect(SafeZone(kind: .buttons, top: 0, height: 1).isVertical)
        #expect(!SafeZone(kind: .title, top: 0, height: 1).isVertical)
    }
}
