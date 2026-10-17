//
//  FaceFollowPathTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Follow face's path behaves like a calm camera operator: still while the face stays in the calm zone, after it smoothly
/// when it leaves, never jumping, never outside the recording, deaf to Vision's jitter.
@Suite("FaceFollowPath")
struct FaceFollowPathTests {
    /// A square crop of a 9:16 recording: 0.5625 of its height, the whole width.
    private let cropWidth = 1.0, cropHeight = 0.5625

    private func analysis(seconds: Double, face: (TimeInterval) -> (x: Double, y: Double)?) -> MotionAnalysis {
        var analysis = MotionAnalysis(duration: seconds, width: 1080, height: 1920)
        analysis.subjects = stride(from: 0.0, to: seconds, by: 0.1).map { time in
            let faces = face(time).map { [NormalizedBox(center: CGPoint(x: $0.x, y: $0.y), width: 0.3, height: 0.17)] } ?? []
            return SubjectSample(time: time, faces: faces, bodies: [])
        }
        analysis.analyzedUntil = seconds
        return analysis
    }

    @Test func aStillFaceKeepsTheFrameStill() throws {
        let path = try #require(FaceFollowPath.make(analysis(seconds: 6) { _ in (0.5, 0.35) }, cropWidth: cropWidth, cropHeight: cropHeight, pace: .natural))
        let ys = stride(from: 0.0, to: 6, by: 0.25).map { path.center(at: $0).y }
        #expect((ys.max() ?? 0) - (ys.min() ?? 0) < 0.000_1)
        // The eyes a little above the middle of the frame.
        #expect(abs(ys[0] - (0.35 + FaceFollowPath.headroom * cropHeight)) < 0.01)
    }

    @Test func visionsJitterDoesNotShakeTheFrame() throws {
        // ±1% of noise, as a face box wobbles from frame to frame.
        let path = try #require(FaceFollowPath.make(analysis(seconds: 6) { time in
            (0.5, 0.45 + 0.01 * sin(time * 37))
        }, cropWidth: cropWidth, cropHeight: cropHeight, pace: .natural))
        let ys = stride(from: 0.0, to: 6, by: 1.0 / 30).map { path.center(at: $0).y }
        #expect((ys.max() ?? 0) - (ys.min() ?? 0) < 0.002)
    }

    @Test func goesAfterAFaceThatLeavesAndLandsSoftly() throws {
        // The face goes from high to low in the frame at 3 s.
        let path = try #require(FaceFollowPath.make(analysis(seconds: 9) { time in
            (0.5, time < 3 ? 0.3 : 0.65)
        }, cropWidth: cropWidth, cropHeight: cropHeight, pace: .natural))
        let ys = stride(from: 0.0, to: 9, by: 1.0 / 30).map { path.center(at: $0).y }
        let steps = zip(ys, ys.dropFirst()).map { abs($1 - $0) }
        // Never a jump: at most the pace's top speed a frame (with a little room for the smoothing).
        #expect((steps.max() ?? 1) <= FollowPace.natural.topSpeed * cropHeight / 30 * 1.2)
        // It got there: the face back inside the calm zone, and still at the end.
        let goal = 0.65 + FaceFollowPath.headroom * cropHeight
        let end = path.center(at: 8.9).y
        #expect(abs(end - min(goal, 1 - cropHeight / 2)) <= FollowPace.natural.deadZone * cropHeight + 0.01)
        #expect(abs(path.center(at: 8.5).y - end) < 0.002)
    }

    @Test func neverLeavesTheRecording() throws {
        let path = try #require(FaceFollowPath.make(analysis(seconds: 4) { _ in (0.5, 0.02) }, cropWidth: cropWidth, cropHeight: cropHeight, pace: .quick))
        for time in stride(from: 0.0, to: 4, by: 0.2) {
            let center = path.center(at: time)
            #expect(center.y >= cropHeight / 2 - 0.000_1 && center.y <= 1 - cropHeight / 2 + 0.000_1)
        }
    }

    @Test func staysOnTheFaceItFollowsWhenAnotherComesIn() throws {
        // The creator on the left; at 2 s a bigger face shows on the right (someone walking close by).
        var made = analysis(seconds: 5) { _ in (0.3, 0.4) }
        for index in made.subjects.indices where made.subjects[index].time >= 2 {
            made.subjects[index] = SubjectSample(time: made.subjects[index].time, faces: [
                NormalizedBox(center: CGPoint(x: 0.85, y: 0.4), width: 0.4, height: 0.23),
                NormalizedBox(center: CGPoint(x: 0.3, y: 0.4), width: 0.3, height: 0.17),
            ], bodies: [])
        }
        // A 9:16 crop of a landscape picture follows sideways.
        made.width = 1920
        made.height = 1080
        let path = try #require(FaceFollowPath.make(made, cropWidth: 0.316, cropHeight: 1, pace: .natural))
        #expect(abs(path.center(at: 4.5).x - path.center(at: 1).x) < 0.01)
    }

    @Test func nothingToFollowWithoutRoomOrAFace() {
        #expect(FaceFollowPath.make(analysis(seconds: 2) { _ in (0.5, 0.5) }, cropWidth: 1, cropHeight: 1, pace: .natural) == nil)
        #expect(FaceFollowPath.make(analysis(seconds: 2) { _ in nil }, cropWidth: cropWidth, cropHeight: cropHeight, pace: .natural) == nil)
    }

    @Test func aBodyWithoutAFaceIsFollowedByItsHead() throws {
        var made = analysis(seconds: 3) { _ in nil }
        made.subjects = made.subjects.map {
            SubjectSample(time: $0.time, faces: [], bodies: [NormalizedBox(x: 0.3, y: 0.5, width: 0.4, height: 0.5)])
        }
        let path = try #require(FaceFollowPath.make(made, cropWidth: cropWidth, cropHeight: cropHeight, pace: .natural))
        #expect(abs(path.center(at: 1).y - min(1 - cropHeight / 2, 0.5 + 0.06 + FaceFollowPath.headroom * cropHeight)) < 0.02)
    }
}
