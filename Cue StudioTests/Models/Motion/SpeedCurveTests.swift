//
//  SpeedCurveTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Speed curves: the timing is the integral of 1 / speed, read both ways, the shape flows without overshooting, and splitting,
/// trimming the handles' reach or mapping a moment through a curved clip never changes how it plays.
@Suite("SpeedCurve")
struct SpeedCurveTests {
    @Test func aFlatCurveIsASpeed() {
        let curve = SpeedCurve(points: [.init(position: 0, speed: 2), .init(position: 1, speed: 2)])
        #expect(abs(curve.editedLength(sourceLength: 6) - 3) < 0.000_1)
        #expect(abs(curve.editedOffset(forSource: 3, sourceLength: 6) - 1.5) < 0.000_1)
        #expect(abs(curve.sourceOffset(forEdited: 1.5, sourceLength: 6) - 3) < 0.000_1)
    }

    @Test func aRampTakesTheTimeItsSpeedsGive() {
        // From 0.5× to 2× on a log scale: ∫ 1/v du, v = 0.5 · 4^u → (1 − 1/4) / (0.5 · ln 4).
        let curve = SpeedCurveTests.ramp
        let expected = (1 - 0.25) / (0.5 * log(4.0))
        #expect(abs(curve.editedLength(sourceLength: 1) - expected) < 0.01, "\(curve.editedLength(sourceLength: 1)) vs \(expected)")
    }

    static let ramp = SpeedCurve(points: [.init(position: 0, speed: 0.5), .init(position: 0.5, speed: 1), .init(position: 1, speed: 2)])

    @Test func readsBothWays() {
        for preset in SpeedCurvePreset.allCases {
            let curve = preset.curve
            for edited in stride(from: 0.0, through: curve.editedLength(sourceLength: 4), by: 0.1) {
                let source = curve.sourceOffset(forEdited: edited, sourceLength: 4)
                #expect(abs(curve.editedOffset(forSource: source, sourceLength: 4) - edited) < 0.002, "\(preset) at \(edited)")
            }
        }
    }

    @Test func neverOvershootsItsPoints() {
        let curve = SpeedCurvePreset.hero.curve
        let speeds = stride(from: 0.0, through: 1, by: 0.01).map { curve.speed(at: $0) }
        #expect((speeds.min() ?? 0) >= 0.4 - 0.000_1 && (speeds.max() ?? 0) <= 2 + 0.000_1)
        // Flat between its two slow points.
        #expect(abs(curve.speed(at: 0.5) - 0.4) < 0.000_1)
    }

    @Test func splittingACurvedClipKeepsHowItPlays() {
        var timeline = EditTimeline(sourceDuration: 10)
        var clip = timeline.segments[0]
        clip.speedCurve = SpeedCurvePreset.bullet.curve
        _ = timeline.replaceSegment(clip)
        let before = timeline.editedDuration
        let moments = stride(from: 0.0, to: before, by: 0.25).map { timeline.sourceTime(forEdited: $0) }
        let split = timeline.split(atEdited: before * 0.4)
        #expect(split)
        #expect(timeline.segments.count == 2)
        // Within half a frame.
        #expect(abs(timeline.editedDuration - before) < 1.0 / 60)
        let after = stride(from: 0.0, to: before, by: 0.25).map { timeline.sourceTime(forEdited: $0) }
        for (a, b) in zip(moments, after) { #expect(abs(a - b) < 0.02) }
    }

    @Test func theTimelineMapsThroughACurve() throws {
        var timeline = EditTimeline(sourceDuration: 8)
        var clip = try #require(timeline.segments.first)
        clip.speedCurve = Self.ramp
        _ = timeline.replaceSegment(clip)
        for source in stride(from: 0.0, through: 8, by: 0.5) {
            let edited = try #require(timeline.editedTime(forSource: source))
            #expect(abs(timeline.sourceTime(forEdited: edited) - source) < 0.01)
        }
        #expect(timeline.hasSpeedChanges)
        #expect(timeline.segments[0].changesSpeed)
    }

    @Test func theHandlesReachBeyondACurvedClipWithoutChangingIt() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        var clip = try #require(timeline.segments.first)
        clip.sourceStart = 2
        clip.sourceEnd = 8
        clip.speedCurve = SpeedCurvePreset.rampUp.curve
        _ = timeline.replaceSegment(clip)
        let reachable = timeline.reachable
        #expect(reachable.segments.count == 3)
        // The edit sits in the reachable timeline after the lead-in, unchanged.
        let lead = timeline.reachableLeadIn
        #expect(abs(lead - 2 / 0.5) < 0.000_1)
        for edited in stride(from: 0.0, to: timeline.editedDuration, by: 0.3) {
            #expect(abs(reachable.sourceTime(forEdited: lead + edited) - timeline.sourceTime(forEdited: edited)) < 0.000_1)
        }
    }

    @Test func aConstantSpeedTakesTheCurveAway() throws {
        var timeline = EditTimeline(sourceDuration: 6)
        var clip = try #require(timeline.segments.first)
        clip.speedCurve = SpeedCurvePreset.hero.curve
        _ = timeline.replaceSegment(clip)
        let set = timeline.setSpeed(1, forSegmentAt: 0)
        #expect(set)
        #expect(timeline.segments[0].speedCurve == nil)
        #expect(abs(timeline.editedDuration - 6) < 0.000_1)
    }

    @Test func savesAndOpensAgain() throws {
        var segment = EditSegment(sourceStart: 0, sourceEnd: 4)
        segment.speedCurve = SpeedCurvePreset.montage.curve
        segment.stabilization = .standard
        let data = try JSONEncoder().encode(segment)
        let opened = try JSONDecoder().decode(EditSegment.self, from: data)
        #expect(opened == segment)
        #expect(abs(opened.duration - segment.duration) < 0.000_1)
        // A clip saved before curves plays at its speed.
        let old = try JSONDecoder().decode(EditSegment.self, from: Data(#"{"id":"\#(UUID().uuidString)","sourceStart":0,"sourceEnd":2,"speed":2}"#.utf8))
        #expect(old.speedCurve == nil && old.stabilization == nil && abs(old.duration - 1) < 0.000_1)
    }
}
