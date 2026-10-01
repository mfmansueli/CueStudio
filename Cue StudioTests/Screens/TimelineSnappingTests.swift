//
//  TimelineSnappingTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("TimelineSnapping")
struct TimelineSnappingTests {
    @Test func sticksWithinSixPoints() {
        // 44 points per second: 6 points is about 0.136 s.
        #expect(TimelineSnapping.snapped(10.1, to: [10], pointsPerSecond: 44) == 10)
        #expect(TimelineSnapping.snapped(10.2, to: [10], pointsPerSecond: 44) == nil)
    }

    @Test func zoomedInTheReachIsShorterInTime() {
        #expect(TimelineSnapping.snapped(10.05, to: [10], pointsPerSecond: 220) == nil)
        #expect(TimelineSnapping.snapped(10.02, to: [10], pointsPerSecond: 220) == 10)
    }

    @Test func theNearestTargetWins() {
        #expect(TimelineSnapping.snapped(5.08, to: [5, 5.15], pointsPerSecond: 44) == 5.15)
        #expect(TimelineSnapping.snapped(5.05, to: [5, 5.15], pointsPerSecond: 44) == 5)
    }
}
