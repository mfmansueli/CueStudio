//
//  TimelineLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

@Suite("TimelineLayout")
struct TimelineLayoutTests {
    private let width: CGFloat = 400
    private let inset = TimelineLayout.handleWidth

    private func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.001 }
    private func near(_ a: TimeInterval, _ b: TimeInterval) -> Bool { abs(a - b) < 0.001 }

    @Test func theWholeTakeFillsTheSpaceBetweenTheHandles() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        #expect(near(layout.pointsPerSecond, (width - 2 * inset) / 10))
        #expect(near(layout.startHandleX, inset))
        #expect(near(layout.endHandleX, width - inset))
        #expect(near(layout.x(forEdited: 5), width / 2))
    }

    @Test func touchAndTimeMapBothWays() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        for time in [0.0, 1.25, 5.32, 9.9, 10] {
            #expect(near(layout.editedTime(atX: layout.x(forEdited: time)), time))
        }
        #expect(layout.editedTime(atX: -50) == 0)
        #expect(layout.editedTime(atX: width + 50) == 10)
    }

    @Test func removedPiecesAreNotOnTheTimeline() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.split(atEdited: 4)
        timeline.split(atEdited: 6)
        timeline.removeSegment(id: timeline.segments[1].id)
        let layout = TimelineLayout(timeline: timeline, width: width)
        // 8 seconds left, with one hairline between the two pieces.
        let scale = (width - 2 * inset - TimelineLayout.joinWidth) / 8
        #expect(near(layout.pointsPerSecond, scale))
        #expect(near(layout.piece(1).minX, inset + 4 * scale + TimelineLayout.joinWidth))
        #expect(layout.piece(1).source == TimeSpan(start: 6, end: 10))
        // On the hairline: where the next piece starts.
        #expect(near(layout.editedTime(atX: inset + 4 * scale + 1), 4))
        #expect(layout.segmentIndex(atX: layout.piece(1).minX + 10) == 1)
        #expect(near(layout.sourceTime(atX: layout.piece(1).minX + scale), 7))
    }

    @Test func trimmedEndsAreNotDrawn() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 2)
        let layout = TimelineLayout(timeline: timeline, width: width)
        let scale = (width - 2 * inset) / 8
        #expect(near(layout.pointsPerSecond, scale))
        #expect(near(layout.startHandleX, inset))
        #expect(layout.sourceTime(atX: inset) == 2)
        #expect(layout.sourceTime(atX: 0) == 2)
        #expect(layout.segmentIndex(atX: inset + scale) == 0)
        #expect(near(layout.editedTime(atX: inset + scale), 1))
    }

    @Test func aTrimFitsTheStripAgain() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 3)
        timeline.trimEnd(to: 8)
        #expect(near(TimelineLayout(timeline: timeline, width: width).pointsPerSecond, (width - 2 * inset) / 5))
    }

    @Test func handlesComeBeforeThePlayheadAndThePlayheadBeforeTheTimeline() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        // The playhead at the start sits on the start handle: the handle wins.
        #expect(layout.target(atX: layout.startHandleX, playheadX: layout.startHandleX) == .handle(.start))
        #expect(layout.target(atX: layout.startHandleX - 20, playheadX: 200) == .handle(.start))
        #expect(layout.target(atX: layout.endHandleX + 20, playheadX: 200) == .handle(.end))
        #expect(layout.target(atX: 205, playheadX: 200) == .playhead)
        #expect(layout.target(atX: 120, playheadX: 200) == .timeline)
    }

    @Test func handlesCloseTogetherGoToTheNearerOne() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: 60)
        #expect(layout.target(atX: 25, playheadX: 0) == .handle(.start))
        #expect(layout.target(atX: 35, playheadX: 0) == .handle(.end))
    }

    @Test func theRedRangeTakesItsEdgesAndTurnsTrimmingOff() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        let removal: ClosedRange<TimeInterval> = 4...6
        let startX = layout.x(forEdited: 4)
        let endX = layout.x(forEdited: 6)
        #expect(layout.target(atX: startX + 6, playheadX: 0, removal: removal) == .removalEdge(.start))
        #expect(layout.target(atX: endX - 10, playheadX: 0, removal: removal) == .removalEdge(.end))
        #expect(layout.target(atX: (startX + endX) / 2, playheadX: 0, removal: removal) == .timeline)
        #expect(layout.target(atX: layout.startHandleX, playheadX: 300, removal: removal) == .timeline)
    }

    @Test func aStripWithoutHandlesUsesTheWholeWidth() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width, inset: 0)
        #expect(near(layout.startHandleX, 0))
        #expect(near(layout.endHandleX, width))
        #expect(near(layout.x(forEdited: 5), width / 2))
    }

    @Test func zoomWidensEverySecond() {
        let timeline = EditTimeline(sourceDuration: 10)
        let fit = TimelineLayout(timeline: timeline, width: width)
        let zoomed = TimelineLayout(timeline: timeline, width: width, zoom: 3, offset: 100)
        #expect(near(zoomed.pointsPerSecond, fit.pointsPerSecond * 3))
        #expect(near(zoomed.x(forEdited: 2), inset - 100 + 2 * zoomed.pointsPerSecond))
        #expect(near(zoomed.editedTime(atX: zoomed.x(forEdited: 2)), 2))
    }

    @Test func frameCountFollowsTheWidthNotTheLength() {
        #expect(TimelineLayout.frameCount(width: 350, tileWidth: 29.25) == 24)
        #expect(TimelineLayout.frameCount(width: 4_000, tileWidth: 29.25) == 60)
        #expect(TimelineLayout.frameCount(width: 40, tileWidth: 29.25) == 8)
    }
}
