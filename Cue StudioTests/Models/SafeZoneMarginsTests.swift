//
//  SafeZoneMarginsTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("SafeZoneMargins")
struct SafeZoneMarginsTests {
    @Test func defaultCustomMarginsLeaveTheMiddleClear() {
        let rect = SafeZoneMargins().unitContentRect
        #expect(abs(rect.minX - 0.06) < 0.0001)
        #expect(abs(rect.minY - 0.11) < 0.0001)
        #expect(abs(rect.maxX - 0.89) < 0.0001)
        #expect(abs(rect.maxY - 0.78) < 0.0001)
    }

    @Test func marginsOutsideTheirRangeAreClamped() {
        let rect = SafeZoneMargins(top: 90, bottom: -5, left: 0, right: 0).unitContentRect
        #expect(abs(rect.minY - 0.3) < 0.0001)
        #expect(rect.maxY == 1)
    }
}
