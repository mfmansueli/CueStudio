//
//  PoseTrackTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
@testable import Cue_Studio

/// A track reads like a CSS `@keyframes`: it holds before the first keyframe and after the last, and eases each stretch with the curve of the
/// keyframe that starts it (the track's own when that has none).
@Suite("PoseTrack")
struct PoseTrackTests {
    @Test func holdsTheFirstPoseBeforeAndTheLastAfter() {
        let track = PoseTrack([.init(1, opacity: 0, scale: 0), .init(2, opacity: 1, scale: 2)])
        #expect(track.pose(at: -5).opacity == 0)
        #expect(track.pose(at: 0.99).scale == 0)
        #expect(track.pose(at: 2).scale == 2)
        #expect(track.pose(at: 99).opacity == 1)
        #expect(track.duration == 2)
    }

    @Test func linearTracksGoStraightBetweenKeyframes() {
        let track = PoseTrack([.init(0, x: 0, y: 10), .init(2, x: 100, y: 30)])
        let middle = track.pose(at: 1)
        #expect(abs(middle.x - 50) < 0.0001)
        #expect(abs(middle.y - 20) < 0.0001)
    }

    @Test func aKeyframesCurveEasesTheStretchThatStartsThere() {
        // ease-out is ahead of linear at the middle; the first stretch has its own curve and the second the track's.
        let track = PoseTrack(curve: .linear, [.init(0, x: 0, curve: .cssEaseOut), .init(1, x: 100), .init(2, x: 200)])
        #expect(track.pose(at: 0.5).x > 50)
        #expect(abs(track.pose(at: 1.5).x - 150) < 0.0001)
    }

    @Test func keyframesGivenOutOfOrderAreSorted() {
        let track = PoseTrack([.init(2, x: 20), .init(0, x: 0)])
        #expect(abs(track.pose(at: 1).x - 10) < 0.0001)
    }

    @Test func anEmptyTrackIsTheDefaultPose() {
        #expect(PoseTrack([]).pose(at: 3) == Pose())
    }

    @Test func sizeAndStretchAreSeparateProperties() {
        let letter = PoseTrack([.init(0, scaleX: 3.4, scaleY: 0.35), .init(1)])
        #expect(letter.pose(at: 0).scaleX == 3.4)
        #expect(letter.pose(at: 0).scale == 1)
        #expect(letter.pose(at: 1).scaleY == 1)
    }
}
