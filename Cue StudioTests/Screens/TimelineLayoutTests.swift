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
        // 8 seconds left, edge to edge: the cut is a line, never a gap.
        let scale = (width - 2 * inset) / 8
        #expect(near(layout.pointsPerSecond, scale))
        #expect(near(layout.piece(1).minX, inset + 4 * scale))
        #expect(near(layout.piece(1).minX, layout.piece(0).maxX))
        #expect(near(layout.joinX(1), layout.piece(1).minX))
        #expect(layout.piece(1).source == TimeSpan(start: 6, end: 10))
        // Right on the cut: where the next piece starts.
        #expect(near(layout.editedTime(atX: inset + 4 * scale), 4))
        #expect(near(layout.editedTime(atX: inset + 4 * scale + 1), 4 + 1 / Double(scale)))
        #expect(layout.segmentIndex(atX: layout.piece(1).minX + 10) == 1)
        #expect(near(layout.sourceTime(atX: layout.piece(1).minX + scale), 7))
    }

    @Test func trimmedEndsStayOnTheStripAndTheHandlesSitWhereTheyTrimmed() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 2)
        let layout = TimelineLayout(timeline: timeline, width: width)
        let scale = (width - 2 * inset) / 10
        #expect(near(layout.pointsPerSecond, scale))
        #expect(near(layout.startHandleX, inset + 2 * scale))
        #expect(near(layout.endHandleX, width - inset))
        #expect(near(layout.piece(0).minX, layout.startHandleX))
        #expect(near(layout.x(forEdited: 0), layout.startHandleX))
        // The trimmed start is still drawn (dimmed), so the handle can go back over it.
        #expect(near(layout.sourceTime(atX: inset), 0))
        #expect(near(layout.sourceTime(atX: inset + scale), 1))
        #expect(layout.segmentIndex(atX: inset + scale) == nil)
        #expect(layout.editedTime(atX: inset + scale) == 0)
        #expect(layout.segmentIndex(atX: layout.startHandleX + scale) == 0)
        #expect(near(layout.editedTime(atX: layout.startHandleX + scale), 1))
    }

    @Test func aTrimKeepsTheScale() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 3)
        timeline.trimEnd(to: 8)
        let layout = TimelineLayout(timeline: timeline, width: width)
        let scale = (width - 2 * inset) / 10
        #expect(near(layout.pointsPerSecond, scale))
        #expect(near(layout.startHandleX, inset + 3 * scale))
        #expect(near(layout.endHandleX, inset + 8 * scale))
        #expect(near(layout.x(forEdited: 5), layout.endHandleX))
        #expect(layout.editedTime(atX: width) == 5)
    }

    @Test func aDeletedSectionLeavesNoGap() {
        var timeline = EditTimeline(sourceDuration: 12)
        timeline.split(atEdited: 4)
        timeline.split(atEdited: 8)
        timeline.removeSegment(id: timeline.segments[1].id)
        timeline.trimStart(to: 1)
        let layout = TimelineLayout(timeline: timeline, width: width)
        // 1 s trimmed (still drawn) + 3 s + 4 s, and nothing where B was.
        let scale = (width - 2 * inset) / 8
        #expect(near(layout.pointsPerSecond, scale))
        #expect(near(layout.piece(1).minX, layout.piece(0).maxX))
        #expect(layout.piece(1).source == TimeSpan(start: 8, end: 12))
        #expect(near(layout.x(forEdited: 3), layout.piece(1).minX))
    }

    @Test func deletingTheLastSectionLeavesOnlyTheFirst() {
        // Split, then Delete B: A alone plays; B is the trimmed end, dimmed, not a gap or a cut.
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.split(atEdited: 4)
        timeline.removeSegment(id: timeline.segments[1].id)
        let layout = TimelineLayout(timeline: timeline, width: width)
        let scale = (width - 2 * inset) / 10
        #expect(layout.timeline.segments.count == 1)
        #expect(near(layout.endHandleX, inset + 4 * scale))
        #expect(layout.join(atX: layout.endHandleX) == nil)
        #expect(near(layout.regions.last?.maxX ?? 0, width - inset))
    }

    @Test func aTapOnACutsMarkFindsTheNearestCut() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.split(atEdited: 3)
        timeline.split(atEdited: 7)
        let layout = TimelineLayout(timeline: timeline, width: width)
        #expect(layout.join(atX: layout.joinX(1) + 5) == 1)
        #expect(layout.join(atX: layout.joinX(2) - TimelineLayout.joinReach + 1) == 2)
        #expect(layout.join(atX: (layout.joinX(1) + layout.joinX(2)) / 2) == nil)
        #expect(layout.join(atX: layout.startHandleX) == nil)
    }

    @Test func whileAHandleIsHeldTheStripStaysAsItWas() {
        // [A | B] cut at 4; the start handle is dragged from A into B.
        var origin = EditTimeline(sourceDuration: 10)
        origin.split(atEdited: 4)
        var trimmed = origin
        trimmed.trimStart(to: 6)
        let held = TimelineLayout(timeline: trimmed, width: width, reach: origin)
        let before = TimelineLayout(timeline: origin, width: width)
        // Same strip, same scale: nothing shifts under the finger.
        #expect(held.regions == before.regions)
        #expect(near(held.pointsPerSecond, before.pointsPerSecond))
        // The handle sits where the finger took it, past the old cut.
        let scale = (width - 2 * inset) / 10
        #expect(near(held.startHandleX, inset + 6 * scale))
        #expect(near(held.sourceTime(atX: held.startHandleX), 6))
        #expect(near(held.endHandleX, width - inset))
        #expect(held.timeline.segments.count == 1)
        #expect(near(held.x(forEdited: 1), inset + 7 * scale))
        #expect(near(held.editedTime(atX: inset + 8 * scale), 2))
    }

    @Test func aHandleHeldAcrossARemovedPartKeepsItsStrip() {
        // [0,3] [6,10]: 3–6 was removed. The start handle dragged past A lands in B.
        var origin = EditTimeline(sourceDuration: 10)
        origin.split(atEdited: 3)
        origin.split(atEdited: 6)
        origin.removeSegment(id: origin.segments[1].id)
        let fit = TimelineLayout(timeline: origin, width: width)
        let x = fit.piece(1).minX + fit.pointsPerSecond
        #expect(near(fit.sourceTime(atX: x), 7))
        var trimmed = origin
        trimmed.trimStart(to: fit.sourceTime(atX: x))
        let held = TimelineLayout(timeline: trimmed, width: width, reach: origin)
        #expect(held.regions == fit.regions)
        #expect(near(held.startHandleX, x))
        // Where the finger is still reads the same moment, so the handle keeps following it.
        #expect(near(held.sourceTime(atX: x), 7))
    }

    @Test func cleanUpsStripShowsTheEditAlone() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 2)
        let layout = TimelineLayout(timeline: timeline, width: width, inset: 0, showsTrimmedEnds: false)
        #expect(near(layout.pointsPerSecond, width / 8))
        #expect(near(layout.startHandleX, 0))
        #expect(near(layout.sourceTime(atX: 0), 2))
    }

    @Test func onTheFramesTheHandlesComeBeforeThePlayhead() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        // The playhead at 00:00 sits on the start handle: on the frames the handle still wins.
        #expect(layout.target(atX: layout.startHandleX, playheadX: layout.startHandleX) == .handle(.start))
        #expect(layout.target(atX: layout.startHandleX - 20, playheadX: layout.startHandleX) == .handle(.start))
        #expect(layout.target(atX: layout.endHandleX, playheadX: layout.endHandleX) == .handle(.end))
        #expect(layout.target(atX: layout.endHandleX + 20, playheadX: 200) == .handle(.end))
        #expect(layout.target(atX: 205, playheadX: 200) == .playhead)
        #expect(layout.target(atX: 120, playheadX: 200) == .timeline)
    }

    @Test func aboveTheFramesThePlayheadAlwaysComesFirst() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        let atStart = layout.startHandleX
        #expect(layout.target(atX: atStart, playheadX: atStart, aboveFrames: true) == .playhead)
        #expect(layout.target(atX: layout.endHandleX, playheadX: layout.endHandleX, aboveFrames: true) == .playhead)
        // Away from the playhead the knob row jumps it; it never trims.
        #expect(layout.target(atX: atStart, playheadX: 200, aboveFrames: true) == .timeline)
    }

    @Test func bothHandlesCatchTheSameMirroredReach() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 3)
        timeline.trimEnd(to: 7)
        let layout = TimelineLayout(timeline: timeline, width: width)
        let outer = TimelineLayout.handleWidth + TimelineLayout.handleOuterReach
        for offset in [-outer, -TimelineLayout.handleWidth / 2, 0, TimelineLayout.handleReach] {
            #expect(layout.handle(atX: layout.startHandleX + offset) == .start)
            #expect(layout.handle(atX: layout.endHandleX - offset) == .end)
        }
        #expect(layout.handle(atX: layout.startHandleX - outer - 1) == nil)
        #expect(layout.handle(atX: layout.endHandleX + outer + 1) == nil)
        #expect(layout.handle(atX: (layout.startHandleX + layout.endHandleX) / 2) == nil)
        // A trimmed start handle is caught where it is, not at the strip's edge.
        #expect(layout.handle(atX: inset) == nil)
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

    @Test func theScrollStaysOnTheStrip() {
        let timeline = EditTimeline(sourceDuration: 10)
        let room = width - 2 * inset
        let scrolledToTheEnd = TimelineLayout(timeline: timeline, width: width, zoom: 4, offset: 10_000)
        #expect(near(scrolledToTheEnd.offset, room * 3))
        #expect(near(scrolledToTheEnd.maxOffset, room * 3))
        #expect(near(scrolledToTheEnd.endHandleX, width - inset))
        #expect(near(scrolledToTheEnd.fitPointsPerSecond, room / 10))
        #expect(near(scrolledToTheEnd.pointsPerSecond, room / 10 * 4))
        #expect(near(TimelineLayout(timeline: timeline, width: width, zoom: 4, offset: -50).offset, 0))
        // At zoom 1 there is nothing to scroll.
        #expect(near(TimelineLayout(timeline: timeline, width: width, offset: 80).offset, 0))
    }

    @Test func aZoomCanKeepAMomentWhereItIs() {
        let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 10), width: width)
        let offset = layout.scrollOffset(placing: 5, atX: 100, zoom: 8)
        let zoomed = layout.zoomed(8, offset: offset)
        #expect(near(zoomed.x(forStrip: 5), 100))
        #expect(near(zoomed.stripTime(atX: 100), 5))
        #expect(near(zoomed.editedTime(atX: 100), 5))
        // Near the start the strip can't scroll back past it.
        #expect(near(layout.scrollOffset(placing: 0.1, atX: 300, zoom: 8), 0))
    }

    @Test func zoomedInTimesStayReal() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 2)
        let layout = TimelineLayout(timeline: timeline, width: width, zoom: 20, offset: 900)
        #expect(near(layout.stripTime(forEdited: 1), 3))
        #expect(near(layout.x(forStrip: 3), layout.x(forEdited: 1)))
        for time in [1.0, 1.04, 1.0333] {
            #expect(near(layout.editedTime(atX: layout.x(forEdited: time)), time))
        }
        // The red range's edges are told apart even a frame apart.
        let removal: ClosedRange<TimeInterval> = 1.0...1.2
        let startX = layout.x(forEdited: removal.lowerBound)
        let endX = layout.x(forEdited: removal.upperBound)
        #expect(endX - startX > 2 * TimelineLayout.removalEdgeReach)
        #expect(layout.target(atX: startX + 4, playheadX: 0, removal: removal) == .removalEdge(.start))
        #expect(layout.target(atX: endX - 4, playheadX: 0, removal: removal) == .removalEdge(.end))
    }

    @Test func frameCountFollowsTheWidthNotTheLength() {
        #expect(TimelineLayout.frameCount(width: 350, tileWidth: 29.25) == 24)
        #expect(TimelineLayout.frameCount(width: 4_000, tileWidth: 29.25) == 60)
        #expect(TimelineLayout.frameCount(width: 40, tileWidth: 29.25) == 8)
    }
}
