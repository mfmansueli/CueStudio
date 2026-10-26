//
//  BlurFollowingTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Following a Blur area: a face through the motion analysis's samples, kept on the same face when another crosses, marked
/// where it's lost and picked up again when it comes back; a drawn area through the tracker's samples, marked where the
/// tracker stopped short; the path thinned; and laid on an area without moving the creator's own keyframes.
@Suite("Blur area following")
struct BlurFollowingTests {
    private func face(_ x: Double, _ y: Double, side: Double = 0.1) -> NormalizedBox {
        NormalizedBox(center: CGPoint(x: x, y: y), width: side, height: side)
    }

    /// Ten samples a second from 0 to `seconds`, each with the faces `faces` gives.
    private func samples(_ seconds: Double, _ faces: (Double) -> [NormalizedBox]) -> [SubjectSample] {
        stride(from: 0.0, through: seconds, by: 0.1).map { SubjectSample(time: $0, faces: faces($0), bodies: []) }
    }

    @Test func aWalkingFaceIsFollowedTheWholeWay() {
        let walk = samples(4) { [face(0.2 + $0 * 0.1, 0.4)] }
        let start = face(0.4, 0.4)
        let area = BlurRegion.area(aroundFace: start)
        let result = BlurFollowing.followFace(walk, area: area, face: start, at: 2, through: TimeSpan(start: 0, end: 4))
        #expect(result.unchecked.isEmpty, "\(result.unchecked)")
        var region = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 4), box: area, subject: .face)
        region = BlurFollowing.applying(result, to: region)
        // At 3.5 s the face is at x 0.55: the area's middle is over it.
        #expect(abs(region.box(at: 3.5).midX - 0.55) < 0.01)
        #expect(abs(region.box(at: 0.5).midX - 0.25) < 0.01)
        #expect(region.isCovered)
        // A straight walk needs only its ends.
        #expect(result.keyframes.count <= 4, "\(result.keyframes.count) keyframes")
    }

    @Test func aFaceThatLeavesIsMarkedAndPickedUpWhenItComesBack() {
        // Gone from 1.5 s to 2.5 s (turned away), then back near where it was.
        let walk = samples(4) { time in time > 1.45 && time < 2.55 ? [] : [face(0.5, 0.4)] }
        let start = face(0.5, 0.4)
        let result = BlurFollowing.followFace(walk, area: BlurRegion.area(aroundFace: start), face: start, at: 0.5, through: TimeSpan(start: 0, end: 4))
        #expect(result.unchecked.count == 1)
        let lost = result.unchecked.first
        #expect((lost?.start ?? 0) <= 1.5 && (lost?.end ?? 0) >= 2.5)
        // Picked up again once it's back; the half second after is checked too (it could be someone else).
        #expect((lost?.end ?? 9) < 3.2, "picked up again once it's back")
    }

    @Test func anotherFaceCrossingNeverTakesTheArea() {
        // The followed face walks right; another walks left through it at 3 s.
        let walk = samples(4) { time in [face(0.2 + time * 0.1, 0.4), face(0.8 - time * 0.1, 0.42)] }
        let start = face(0.3, 0.4)
        let result = BlurFollowing.followFace(walk, area: BlurRegion.area(aroundFace: start), face: start, at: 1, through: TimeSpan(start: 0, end: 4))
        var region = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 4), box: BlurRegion.area(aroundFace: start), subject: .face)
        region = BlurFollowing.applying(result, to: region)
        // After the crossing it's still on the face walking right (0.58 at 3.8 s; the other is at 0.42).
        #expect(abs(region.box(at: 3.8).midX - 0.58) < 0.03, "\(region.box(at: 3.8).midX)")
        // Where they overlap, it's marked to check.
        #expect(result.unchecked.contains { $0.contains(3) }, "\(result.unchecked)")
    }

    @Test func aFaceLostForAWhileIsNotPickedUpFarAwayOrAtAnotherSize() {
        // The face walks right fast, vanishes at 1 s; at 2 s someone else appears far to the left, and a big face near.
        let walk = samples(3) { time in
            if time < 1 { return [face(0.3 + time * 0.2, 0.4)] }
            if time < 2 { return [] }
            return [face(0.05, 0.4), face(0.5, 0.4, side: 0.25)]
        }
        let start = face(0.3, 0.4)
        let result = BlurFollowing.followFace(walk, area: BlurRegion.area(aroundFace: start), face: start, at: 0, through: TimeSpan(start: 0, end: 3))
        // Never picked up: lost from 0.9 s to the end.
        #expect(result.unchecked.contains { $0.start <= 1 && $0.end >= 2.95 }, "\(result.unchecked)")
    }

    @Test func whereTheAnalysisHasNothingItIsMarked() {
        let walk = samples(2) { _ in [face(0.5, 0.4)] }
        let start = face(0.5, 0.4)
        // The area lasts 4 s, the analysis reached 2 s.
        let result = BlurFollowing.followFace(walk, area: BlurRegion.area(aroundFace: start), face: start, at: 1, through: TimeSpan(start: 0, end: 4))
        #expect(result.unchecked.contains { $0.start <= 2.1 && $0.end >= 3.9 })
    }

    @Test func aDrawnAreaFollowsTheTrackerAndIsMarkedWhereItStopped() {
        let tracked = NormalizedBox(x: 0.4, y: 0.4, width: 0.2, height: 0.1)
        let ahead = stride(from: 1.0, through: 2.0, by: 1.0 / 30).map { time in
            TrackSample(time: time, box: NormalizedBox(x: 0.4 + (time - 1) * 0.1, y: 0.4, width: 0.2, height: 0.1), confidence: 0.9)
        }
        let behind = stride(from: 0.0, to: 1.0, by: 1.0 / 30).map { time in
            TrackSample(time: time, box: NormalizedBox(x: 0.4 - (1 - time) * 0.1, y: 0.4, width: 0.2, height: 0.1), confidence: 0.9)
        }
        let result = BlurFollowing.followObject(ahead: ahead, behind: behind, area: tracked, tracked: tracked, at: 1, through: TimeSpan(start: 0, end: 3))
        // Lost after 2 s: the last second is unchecked.
        #expect(result.unchecked == [TimeSpan(start: 2, end: 3)])
        var region = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 3), box: tracked)
        region = BlurFollowing.applying(result, to: region)
        #expect(abs(region.box(at: 1.5).x - 0.45) < 0.005)
        #expect(abs(region.box(at: 0.5).x - 0.35) < 0.005)
        #expect(!region.isCovered)
    }

    @Test func followingAgainKeepsTheCreatorsOwnSpots() {
        var region = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 4), box: face(0.5, 0.5))
        let mine = BlurKeyframe(time: 2, box: face(0.7, 0.7), isSet: true)
        region.keyframes = [BlurKeyframe(time: 1, box: face(0.1, 0.1)), mine]
        region.markUnchecked(TimeSpan(start: 1.5, end: 3))
        let result = BlurFollowing.Result(
            keyframes: [BlurKeyframe(time: 1, box: face(0.5, 0.5)), BlurKeyframe(time: 2, box: face(0.6, 0.6)), BlurKeyframe(time: 3, box: face(0.6, 0.6))],
            unchecked: [TimeSpan(start: 3.5, end: 4)], reached: TimeSpan(start: 0, end: 4)
        )
        let next = BlurFollowing.applying(result, to: region)
        #expect(next.keyframes.contains(mine))
        #expect(!next.keyframes.contains { $0.time == 2 && $0.isSet != true }, "the followed one at the creator's spot gives way")
        #expect(next.openUnchecked == [TimeSpan(start: 3.5, end: 4)])
        #expect(next.isFollowed)
    }

    @Test func thinningKeepsTheTurnsOfThePath() {
        // Right for a second, then down.
        let keyframes = stride(from: 0.0, through: 2.0, by: 1.0 / 30).map { time in
            BlurKeyframe(time: time, box: face(min(time, 1) * 0.4 + 0.1, max(0, time - 1) * 0.4 + 0.1))
        }
        let thinned = BlurFollowing.thinned(keyframes)
        #expect(thinned.count >= 3 && thinned.count <= 6, "\(thinned.count)")
        #expect(thinned.first == keyframes.first && thinned.last == keyframes.last)
        #expect(thinned.contains { abs($0.time - 1) < 0.05 }, "the corner")
    }
}
