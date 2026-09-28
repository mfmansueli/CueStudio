//
//  TimelineZoomTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The Trim timeline's automatic zoom, on a two-minute take in a 340 pt strip (308 pt of room,
/// about 2.6 pt a second at zoom 1).
@Suite("TimelineZoom")
struct TimelineZoomTests {
    private let room: CGFloat = 308
    private var fit: CGFloat { room / 120 }
    private var maximum: CGFloat { TimelineZoom.maximum(fitPointsPerSecond: fit, frameRate: 30) }

    private func level(_ seconds: TimeInterval, from current: CGFloat = 1, zoomsOut: Bool = true) -> CGFloat {
        TimelineZoom.level(
            forSelection: seconds, current: current, fitPointsPerSecond: fit, room: room, maximum: maximum, zoomsOut: zoomsOut
        )
    }

    private func width(_ seconds: TimeInterval, at zoom: CGFloat) -> CGFloat {
        CGFloat(seconds) * fit * zoom
    }

    @Test func theDeepestZoomShowsEachFrameTwelvePointsWide() {
        #expect(abs(fit * maximum / 30 - TimelineZoom.pointsPerFrameAtMaximum) < 0.001)
        #expect(abs(TimelineZoom.maximum(fitPointsPerSecond: fit, frameRate: 60) - 2 * maximum) < 0.001)
        // A take short enough to show frame by frame already doesn't zoom.
        #expect(TimelineZoom.maximum(fitPointsPerSecond: 1_000, frameRate: 30) == 1)
        #expect(TimelineZoom.maximum(fitPointsPerSecond: 0, frameRate: 30) == 1)
    }

    @Test func theStepsClimbEvenlyToTheMaximum() {
        let levels = TimelineZoom.levels(upTo: maximum)
        #expect(levels.first == 1)
        #expect(levels.last == maximum)
        #expect(levels == levels.sorted())
        for (low, high) in zip(levels, levels.dropFirst()) {
            #expect(high / low < 1.8)
        }
        #expect(TimelineZoom.levels(upTo: 1) == [1])
    }

    @Test func aLargeSelectionStaysAtTheWholeTake() {
        #expect(level(30) == 1)
        #expect(level(120) == 1)
    }

    @Test func theSmallerTheSelectionTheDeeperTheZoom() {
        var previous: CGFloat = 1
        for seconds in [10.0, 4, 2, 1, 0.5, 0.25] {
            let zoom = level(seconds)
            #expect(zoom > previous || zoom == maximum)
            if zoom < maximum {
                #expect(width(seconds, at: zoom) >= room * TimelineZoom.zoomInTo)
                #expect(width(seconds, at: zoom) <= room * TimelineZoom.zoomOutAbove)
            }
            previous = zoom
        }
    }

    @Test func aFewFramesGetFramePrecision() {
        let zoom = level(0.2)
        #expect(zoom == maximum)
        #expect(TimelineZoom.isFramePrecise(pointsPerSecond: fit * zoom, frameRate: 30))
        #expect(!TimelineZoom.isFramePrecise(pointsPerSecond: fit, frameRate: 30))
        // Still wide enough to hold both edges apart.
        #expect(width(0.2, at: zoom) >= room * TimelineZoom.zoomInBelow)
    }

    @Test func smallChangesKeepTheZoom() {
        // From 1.2 s down to 0.9 s, or up to 1.6 s, the strip doesn't move.
        let zoom = level(1.2)
        #expect(zoom > 1)
        for seconds in [0.9, 1.0, 1.4, 1.6] {
            #expect(level(seconds, from: zoom) == zoom)
        }
    }

    @Test func growingTheSelectionZoomsBackOut() {
        let zoom = level(0.5)
        let wider = level(4, from: zoom)
        #expect(wider < zoom)
        #expect(width(4, at: wider) <= room * TimelineZoom.zoomOutTo)
        // Once zoomed by hand, the automatic zoom never zooms out.
        #expect(level(4, from: zoom, zoomsOut: false) == zoom)
    }

    @Test func stepsFollowTheLadder() {
        #expect(TimelineZoom.step(from: 1, zoomingIn: true, maximum: maximum) == 1.5)
        #expect(TimelineZoom.step(from: 3, zoomingIn: true, maximum: maximum) == 4)
        #expect(TimelineZoom.step(from: 1.5, zoomingIn: false, maximum: maximum) == 1)
        #expect(TimelineZoom.step(from: maximum, zoomingIn: true, maximum: maximum) == maximum)
        #expect(TimelineZoom.step(from: 1, zoomingIn: false, maximum: maximum) == 1)
    }
}
