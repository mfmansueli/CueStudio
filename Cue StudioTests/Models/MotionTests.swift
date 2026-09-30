//
//  MotionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Keyframed motion read at a moment, easing, section zooms, and how they keep through saving and
/// edits.
@Suite("Motion")
struct MotionTests {
    private let left = OverlayPoint(x: 0.2, y: 0.5)
    private let right = OverlayPoint(x: 0.8, y: 0.5)

    @Test func motionHoldsItsEndsAndMovesBetweenThem() throws {
        let motion = OverlayMotion([
            OverlayKeyframe(time: 3, center: right, scale: 2, opacity: 0, easing: .linear),
            OverlayKeyframe(time: 1, center: left),
        ])
        #expect(motion.state(at: 0)?.center == left)
        #expect(motion.state(at: 5)?.center == right)
        let middle = try #require(motion.state(at: 2))
        #expect(abs(middle.center.x - 0.5) < 0.000_1)
        #expect(abs(middle.scale - 1.5) < 0.000_1)
        #expect(abs(middle.opacity - 0.5) < 0.000_1)
        #expect(OverlayMotion([]).state(at: 1) == nil)
    }

    @Test func smoothEasingStartsAndLandsSoftly() {
        #expect(KeyframeEasing.smooth.apply(0.5) == 0.5)
        #expect(KeyframeEasing.smooth.apply(0.25) < 0.25)
        #expect(KeyframeEasing.smooth.apply(0.75) > 0.75)
        #expect(KeyframeEasing.linear.apply(0.25) == 0.25)
        #expect(KeyframeEasing.linear.apply(2) == 1)
    }

    @Test func keyframesStayInRange() {
        let keyframe = OverlayKeyframe(time: -1, center: left, scale: 9, opacity: 3)
        #expect(keyframe.time == 0)
        #expect(keyframe.scale == OverlayKeyframe.scaleRange.upperBound)
        #expect(keyframe.opacity == 1)
    }

    @Test func sectionZoomsGoWhereTheySay() {
        #expect(SectionZoom.pushIn.scale(at: 0) == 1)
        #expect(abs(SectionZoom.pushIn.scale(at: 1) - (1 + SectionZoom.depth)) < 0.000_1)
        #expect(abs(SectionZoom.pullOut.scale(at: 0) - (1 + SectionZoom.depth)) < 0.000_1)
        #expect(SectionZoom.pullOut.scale(at: 1) == 1)
        #expect(SectionZoom.punchIn.scale(at: 0) == SectionZoom.punchIn.scale(at: 1))
        let window = ZoomWindow(zoom: .pushIn, start: 10, duration: 4)
        #expect(window.scale(at: 10) == 1)
        #expect(abs(window.scale(at: 14) - (1 + SectionZoom.depth)) < 0.000_1)
    }

    @Test func aZoomTravelsWithItsSection() throws {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.setZoom(.pushIn, forSegmentAt: 0)
        timeline.split(atEdited: 10)
        #expect(timeline.segments.map(\.zoom) == [.pushIn, .pushIn])
        let copy = timeline.duplicateSegment(id: timeline.segments[1].id)
        #expect(copy != nil)
        #expect(timeline.segments[2].zoom == .pushIn)
        let decoded = try JSONDecoder().decode(EditTimeline.self, from: JSONEncoder().encode(timeline))
        #expect(decoded.segments.map(\.zoom) == [.pushIn, .pushIn, .pushIn])
    }

    @Test func oldProjectsReadWithoutMotion() throws {
        let segment = #"{"id": "\#(UUID().uuidString)", "sourceStart": 0, "sourceEnd": 3}"#
        #expect(try JSONDecoder().decode(EditSegment.self, from: Data(segment.utf8)).zoom == nil)
        let edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        object["captionAnimation"] = nil
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.captionAnimation == .line)
        var text = TextOverlay(role: .title, style: .clean, span: TimeSpan(start: 0, end: 1))
        text.keyframes = []
        let json = try #require(String(data: JSONEncoder().encode(text), encoding: .utf8))
        #expect(!json.contains("keyframes"))
    }
}
