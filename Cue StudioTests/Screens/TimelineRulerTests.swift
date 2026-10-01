//
//  TimelineRulerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("TimelineRuler")
struct TimelineRulerTests {
    @Test func theStepFollowsTheZoom() {
        #expect(TimelineRuler.step(at: 44 * 5) == 0.5)
        #expect(TimelineRuler.step(at: 44 * 2) == 1)
        #expect(TimelineRuler.step(at: 44) == 2)
        #expect(TimelineRuler.step(at: 44 * 0.35) == 5)
    }

    @Test func everySecondTickIsMajorWithALabel() {
        let ticks = TimelineRuler.ticks(from: 0, to: 9, duration: 21.6, pointsPerSecond: 44)
        #expect(ticks.map(\.time) == [0, 2, 4, 6, 8])
        #expect(ticks.map(\.isMajor) == [true, false, true, false, true])
        #expect(ticks.map(\.label) == ["00:00", nil, "00:04", nil, "00:08"])
    }

    @Test func ticksStayInsideTheVideo() {
        let ticks = TimelineRuler.ticks(from: -10, to: 100, duration: 21.6, pointsPerSecond: 44)
        #expect(ticks.first?.time == 0)
        #expect((ticks.last?.time ?? 0) <= 21.6)
        #expect(TimelineRuler.ticks(from: 30, to: 40, duration: 21.6, pointsPerSecond: 44).isEmpty)
    }

    @Test func zoomedInTicksAreHalfSeconds() {
        let ticks = TimelineRuler.ticks(from: 60, to: 62, duration: 300, pointsPerSecond: 220)
        #expect(ticks.map(\.time) == [60, 60.5, 61, 61.5, 62])
        #expect(ticks.first?.label == "01:00")
    }
}
