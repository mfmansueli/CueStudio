//
//  SkinFaceTrackerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// What keeps the smoothing from flickering: faces that stay the same faces, move smoothly, fade in and out, and are forgotten at a cut or a seek.
@Suite("Skin Smoothing face tracker")
struct SkinFaceTrackerTests {
    private typealias Calibration = SkinSmoothingCalibration

    private func face(shiftedBy shift: CGPoint = .zero) -> FaceLandmarks { SkinFaceFixture.landmarks(shiftedBy: shift) }

    private func presence(_ tracker: SkinFaceTracker, at time: TimeInterval) -> [Double] { tracker.faces(at: time).map(\.presence) }

    @Test func aFaceFoundOnTheFirstFrameIsThereInFullAtOnce() {
        var tracker = SkinFaceTracker()
        tracker.update(with: [face()], at: 10)
        #expect(presence(tracker, at: 10) == [1], "a paused frame shows the whole effect")
    }

    @Test func noFacesIsNoFaces() {
        var tracker = SkinFaceTracker()
        tracker.update(with: [], at: 0)
        #expect(tracker.faces(at: 0).isEmpty)
    }

    @Test func aFaceThatEntersTheShotFadesIn() {
        var tracker = SkinFaceTracker()
        tracker.update(with: [], at: 1)
        tracker.update(with: [], at: 1.03)
        // Born at 0: not drawn yet (a face with no presence isn't listed), then more and more of it, frame after frame.
        var seen: [Double] = []
        for frame in 0...5 {
            let time = 1.06 + Double(frame) * 0.03
            tracker.update(with: [face()], at: time)
            seen.append(presence(tracker, at: time).first ?? 0)
        }
        #expect(seen[0] < 0.05)
        #expect(zip(seen, seen.dropFirst()).allSatisfy { $0 < $1 || $0 == 1 })
        #expect(seen.last == 1, "in full after \(Calibration.fadeInTime) s")
    }

    @Test func aFaceThatStopsBeingFoundIsHeldAndFadesOut() {
        var tracker = SkinFaceTracker()
        tracker.update(with: [face()], at: 0)
        tracker.update(with: [face()], at: 0.03)
        tracker.update(with: [], at: 0.06)
        let blink = presence(tracker, at: 0.06)
        #expect(blink.count == 1 && blink[0] > 0.9, "one frame the detector misses is not seen")
        let later = presence(tracker, at: 0.03 + Calibration.holdTime / 2)[0]
        #expect(later > 0 && later < 1)
        tracker.update(with: [], at: 0.03 + Calibration.holdTime + 0.01)
        #expect(tracker.faces(at: 0.03 + Calibration.holdTime + 0.01).isEmpty, "gone once the hold is over")
    }

    @Test func aBlinkOfTheDetectorNeverJumpsMoreThanAFewPercentAFrame() {
        var tracker = SkinFaceTracker()
        var values: [Double] = []
        for frame in 0..<30 {
            let time = Double(frame) / 30
            tracker.update(with: frame == 10 ? [] : [face()], at: time)
            values.append(presence(tracker, at: time).first ?? 0)
        }
        for (previous, next) in zip(values, values.dropFirst()) { #expect(abs(next - previous) < 0.35) }
        #expect(values.min() ?? 0 > 0.6)
    }

    @Test func aFaceFoundNearItsLastPlaceIsTheSameFaceAndMovesPartWayThere() throws {
        var tracker = SkinFaceTracker()
        tracker.update(with: [face()], at: 0)
        let first = try #require(tracker.faces(at: 0).first)
        tracker.update(with: [face(shiftedBy: CGPoint(x: 40, y: 0))], at: 0.03)
        let moved = try #require(tracker.faces(at: 0.03).first)
        #expect(moved.id == first.id)
        let from = first.landmarks.box.minX, to = face(shiftedBy: CGPoint(x: 40, y: 0)).box.minX
        #expect(moved.landmarks.box.minX > from && moved.landmarks.box.minX < to, "steady: it follows, but not all the way in one step")
        #expect(abs(moved.landmarks.box.minX - (from + (to - from) * Calibration.followRate)) < 0.000_1)
    }

    @Test func aFaceFarFromEveryOneBeforeIsANewFace() throws {
        var tracker = SkinFaceTracker()
        tracker.update(with: [face()], at: 0)
        let first = try #require(tracker.faces(at: 0).first)
        tracker.update(with: [face(shiftedBy: CGPoint(x: 400, y: 0))], at: 0.03)
        let ids = tracker.faces(at: 0.06).map(\.id)
        #expect(ids.count == 2 && ids.contains(first.id), "the first is held while the new one comes in")
        #expect(Set(ids).count == 2)
    }

    @Test func twoFacesKeepTheirOwnIdentitiesFromFrameToFrame() throws {
        var tracker = SkinFaceTracker()
        let left = face(), right = face(shiftedBy: CGPoint(x: 600, y: 0))
        tracker.update(with: [left, right], at: 0)
        let before = Dictionary(uniqueKeysWithValues: tracker.faces(at: 0).map { ($0.landmarks.box.minX.roundedToHundredths, $0.id) })
        tracker.update(with: [right, left], at: 0.03)
        let after = tracker.faces(at: 0.03)
        #expect(after.count == 2)
        for face in after {
            #expect(before[face.landmarks.box.minX.roundedToHundredths] == face.id)
        }
    }

    @Test func aSeekForgetsEverything() {
        var tracker = SkinFaceTracker()
        tracker.update(with: [face()], at: 5)
        tracker.update(with: [face()], at: 5.03)
        // Backwards: nothing of before is kept, and the face found now is there in full.
        tracker.update(with: [face(shiftedBy: CGPoint(x: 400, y: 0))], at: 2)
        let faces = tracker.faces(at: 2)
        #expect(faces.count == 1 && faces[0].presence == 1)
        // Forward past the gap does the same.
        tracker.update(with: [], at: 2 + Calibration.continuityGap + 1)
        #expect(tracker.faces(at: 2 + Calibration.continuityGap + 1).isEmpty)
    }

    @Test func continuityIsAboutTheLastLookInTime() {
        var tracker = SkinFaceTracker()
        #expect(!tracker.isContinuous(at: 0))
        tracker.update(with: [], at: 1)
        #expect(tracker.isContinuous(at: 1) && tracker.isContinuous(at: 1.1))
        #expect(!tracker.isContinuous(at: 0.9) && !tracker.isContinuous(at: 1 + Calibration.continuityGap + 0.01))
        tracker.reset()
        #expect(!tracker.isContinuous(at: 1))
    }

    /// A frame between two detections is not a frame of the old position: the face goes on at the speed it was moving.
    @Test func aMovingFaceIsCarriedAlongBetweenDetections() {
        var tracker = SkinFaceTracker()
        let interval = Calibration.detectionInterval
        for step in 0..<6 { tracker.update(with: [face(shiftedBy: CGPoint(x: Double(step) * 20, y: 0))], at: Double(step) * interval) }
        let seen = tracker.faces(at: 5 * interval)[0].landmarks.center.x
        let halfway = tracker.faces(at: 5.5 * interval)[0].landmarks.center.x
        let later = tracker.faces(at: 6 * interval)[0].landmarks.center.x
        #expect(halfway > seen && later > halfway, "moving on, a little each frame: \(seen) \(halfway) \(later)")
        #expect(later - seen < 2 * (halfway - seen) + 0.0001, "at a steady pace")
        // And never far past where it was seen: carried for `extrapolationLimit` at most.
        let far = tracker.faces(at: 5 * interval + 10)
        #expect(far.isEmpty || far[0].landmarks.center.x - seen < 0.5)
    }

    /// The effect is as strong between two detections as at them: it fades only once the next detection is overdue.
    @Test func aFaceStaysFullyPresentUntilTheNextDetectionIsOverdue() {
        var tracker = SkinFaceTracker()
        tracker.update(with: [face()], at: 0)
        let interval = Calibration.detectionInterval
        for fraction in stride(from: 0.0, through: 1.0, by: 0.25) {
            #expect(presence(tracker, at: interval * fraction) == [1], "\(fraction) of the way to the next detection")
        }
        let overdue = presence(tracker, at: interval + Calibration.holdTime / 2)
        #expect(overdue.count == 1 && overdue[0] < 1 && overdue[0] > 0, "half way through the hold")
        #expect(presence(tracker, at: interval + Calibration.holdTime + 0.01).isEmpty)
    }

    @Test func theLargestFaceComesFirst() {
        var tracker = SkinFaceTracker()
        var small = face(shiftedBy: CGPoint(x: 600, y: 0))
        small.box = CGRect(x: small.box.minX, y: small.box.minY, width: small.box.width / 2, height: small.box.height / 2)
        tracker.update(with: [small, face()], at: 0)
        let sizes = tracker.faces(at: 0).map { $0.landmarks.box.width * $0.landmarks.box.height }
        #expect(sizes == sizes.sorted(by: >))
    }
}

private extension CGFloat {
    var roundedToHundredths: CGFloat { (self * 100).rounded() / 100 }
}
