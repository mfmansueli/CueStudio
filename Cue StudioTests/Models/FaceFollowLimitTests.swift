//
//  FaceFollowLimitTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Follow face can't promise in a recording (F16), read from its analysis: nobody found, more than one face, a face in part of it.
@Suite("FaceFollowLimit")
struct FaceFollowLimitTests {
    private let face = NormalizedBox(x: 0.4, y: 0.3, width: 0.2, height: 0.15)
    private let otherFace = NormalizedBox(x: 0.1, y: 0.35, width: 0.1, height: 0.08)
    private let body = NormalizedBox(x: 0.3, y: 0.2, width: 0.4, height: 0.7)

    /// Ten moments a second for `count` moments, each with the faces and bodies `sample` gives.
    private func analysis(_ count: Int, _ sample: (Int) -> (faces: [NormalizedBox], bodies: [NormalizedBox])) -> MotionAnalysis {
        var analysis = MotionAnalysis(duration: Double(count) / 10, width: 1080, height: 1920)
        analysis.subjects = (0..<count).map { index in
            let found = sample(index)
            return SubjectSample(time: Double(index) / 10, faces: found.faces, bodies: found.bodies)
        }
        analysis.analyzedUntil = analysis.duration
        return analysis
    }

    @Test func oneFaceAllAlongHasNoLimit() {
        #expect(FaceFollowLimit.of(analysis(50) { _ in ([face], [body]) }) == nil)
    }

    @Test func nobodyIsNoFace() {
        let empty = analysis(50) { _ in ([], []) }
        #expect(FaceFollowLimit.of(empty) == .noFace)
        #expect(FaceFollowLimit.of(empty)?.note == "No face found in this video")
    }

    @Test func twoFacesInAGoodPartSaysTheFrameFollowsOne() {
        // A second face in 3 moments of 10: more than the quarter that counts.
        let crowded = analysis(50) { $0 % 10 < 3 ? ([face, otherFace], []) : ([face], []) }
        #expect(FaceFollowLimit.of(crowded) == .severalFaces)
        // A face passing by in 1 moment of 10 isn't worth a line.
        #expect(FaceFollowLimit.of(analysis(50) { $0 % 10 == 0 ? ([face, otherFace], []) : ([face], []) }) == nil)
    }

    /// Found in under 60% of the moments (a weak detection, the face turned away): where it's lost the frame holds still.
    @Test func aFaceInPartOfTheVideoSaysTheFrameHoldsStill() {
        let partly = analysis(50) { $0 < 25 ? ([face], []) : ([], []) }
        #expect(FaceFollowLimit.of(partly) == .partlyFound)
        // A person whose face doesn't show still counts as found (the path follows their head).
        #expect(FaceFollowLimit.of(analysis(50) { $0 < 25 ? ([face], []) : ([], [body]) }) == nil)
    }
}
