//
//  EyeGazePlanTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Eye Contact's decisions: corrected while the person reads, by the angle the face's distance gives, eased in and out around blinks,
/// lost faces, other people, small eyes, a turned head, looks away and blurred frames, and the same answer for the same frame however
/// it's asked.
@Suite("EyeGazePlan")
struct EyeGazePlanTests {
    /// The test eyes' angle: their iris (31.5 px across half) in a 1080-px-wide frame.
    private let full = EyeGazePlan.degrees(irisRadius: EyeTestData.irisShare * EyeTestData.eyeWidth, frameWidth: 1080)

    @Test func steadyReadingIsCorrectedByTheMeasuredAngleAtTheStrengthAsked() throws {
        let plan = EyeGazePlan.make(EyeTestData.analysis())
        let frame = try #require(plan.frame(at: 5, strength: 1))
        #expect(full > 5 && full <= EyeContactCalibration.mostDegrees)
        #expect(abs(frame.degrees - full) < 0.01)
        #expect(abs((plan.frame(at: 5, strength: 0.6)?.degrees ?? 0) - 0.6 * full) < 0.01)
        #expect(plan.summary(in: [TimeSpan(start: 0, end: 10)]).corrected == 1)
    }

    @Test func aCloserFaceIsTurnedFurtherUpToTheMost() {
        let near = EyeGazePlan.degrees(irisRadius: 60, frameWidth: 1080), far = EyeGazePlan.degrees(irisRadius: 15, frameWidth: 1080)
        #expect(near > far)
        #expect(EyeGazePlan.degrees(irisRadius: 400, frameWidth: 1080) == EyeContactCalibration.mostDegrees)
        #expect(EyeGazePlan.degrees(irisRadius: 0, frameWidth: 1080) == 0)
    }

    @Test func aBlinkKeepsItsOwnEyesAndTheCorrectionEasesAroundIt() {
        // Closed from 4.0 to 4.1 s.
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in
            EyeTestData.face(opening: (4.0..<4.1).contains(time) ? 0.03 : 0.3)
        })
        #expect(plan.frame(at: 4.05, strength: 1) == nil)
        // The frames next to it get only a little (the correction leaves before the lids fall and comes back after they're up).
        #expect((plan.frame(at: 4.0 - 1.0 / 30, strength: 1)?.degrees ?? 0) < 0.25 * full)
        #expect((plan.frame(at: 4.1 + 1.0 / 30, strength: 1)?.degrees ?? 0) < 0.25 * full)
        #expect(abs((plan.frame(at: 3.5, strength: 1)?.degrees ?? 0) - full) < 0.01)
        #expect(abs((plan.frame(at: 4.6, strength: 1)?.degrees ?? 0) - full) < 0.01)
        #expect(plan.holds[plan.index(at: 4.05) ?? -1] == .blink)
    }

    @Test func aBlinkIsNeverOpened() {
        // Lids half way down: under the person's usual opening's threshold → as filmed.
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in
            EyeTestData.face(opening: (6.0..<6.2).contains(time) ? 0.13 : 0.3)
        })
        #expect(plan.frame(at: 6.1, strength: 1) == nil)
    }

    @Test func noFaceAnotherPersonAndADoubtfulFaceKeepTheFrameAsFilmed() {
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in
            switch time {
            case 1..<2: nil
            case 3..<4: EyeTestData.face(crowded: true)
            case 5..<6: EyeTestData.face(confidence: 0.2)
            default: EyeTestData.face()
            }
        })
        #expect(plan.frame(at: 1.5, strength: 1) == nil)
        #expect(plan.frame(at: 3.5, strength: 1) == nil)
        #expect(plan.frame(at: 5.5, strength: 1) == nil)
        #expect(plan.holds[plan.index(at: 1.5) ?? 0] == .noFace)
        #expect(plan.holds[plan.index(at: 3.5) ?? 0] == .otherPeople)
        #expect(plan.frame(at: 7.5, strength: 1) != nil)
    }

    @Test func eyesTooSmallAreLeftAlone() {
        let analysis = EyeTestData.analysis { _ in
            var face = EyeTestData.face()
            // Shrink the eyes to 20 px wide around their centers.
            face.eyes = face.eyes.map { eye in
                let center = (eye.outerCorner + eye.innerCorner) / 2
                let scale = 20 / EyeTestData.eyeWidth
                return EyeShape(contour: eye.contour.map { center + ($0 - center) * scale }, iris: center, irisRadius: eye.irisRadius * scale)
            }
            return face
        }
        let plan = EyeGazePlan.make(analysis)
        #expect(plan.frame(at: 5, strength: 1) == nil)
        #expect(plan.holds[plan.index(at: 5) ?? 0] == .smallEyes)
    }

    @Test func aTurnedOrTiltedHeadEasesOff() {
        let tilted = EyeGazePlan.make(EyeTestData.analysis { _ in EyeTestData.face(roll: 40) })
        #expect(tilted.frame(at: 5, strength: 1) == nil)
        let slightly = EyeGazePlan.make(EyeTestData.analysis { _ in EyeTestData.face(roll: 5) })
        #expect(slightly.frame(at: 5, strength: 1) != nil)
    }

    @Test func lookingAtTheLensOrFarAwayIsLeftAlone() {
        // Reading for most of it; from 5 to 6 s the eyes go up (about 21°), from 7 to 8 s far down (about 28°).
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in
            switch time {
            case 5..<6: EyeTestData.face(gaze: SIMD2(0, -0.15))
            case 7..<8: EyeTestData.face(gaze: SIMD2(0, 0.2))
            default: EyeTestData.face()
            }
        })
        #expect(plan.frame(at: 5.5, strength: 1) == nil)
        #expect(plan.frame(at: 7.5, strength: 1) == nil)
        #expect(plan.holds[plan.index(at: 5.5) ?? 0] == .lookingAway)
        #expect(plan.frame(at: 3, strength: 1) != nil)
    }

    @Test func aBlurredMomentIsLeftAlone() {
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in
            var face = EyeTestData.face()
            if (5..<5.5).contains(time) { face.sharpness = 8 }
            return face
        })
        #expect(plan.frame(at: 5.25, strength: 1) == nil)
        #expect(plan.holds[plan.index(at: 5.25) ?? 0] == .blurred)
        #expect(plan.frame(at: 7, strength: 1) != nil)
    }

    @Test func aFaceThatJumpsIsTreatedAsLostForAMoment() {
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in
            EyeTestData.face(offset: time >= 5 ? CGPoint(x: 400, y: 0) : .zero)
        })
        #expect(plan.frame(at: 5, strength: 1) == nil)
        #expect(plan.frame(at: 6, strength: 1) != nil)
    }

    @Test func aMomentNotAnalyzedAroundIsNotCorrectedYet() {
        var analysis = EyeContactAnalysis(duration: 10, width: 1080, height: 1920, fileStamp: "a")
        analysis.frameRate = 30
        let span = TimeSpan(start: 3, end: 6)
        let frames = stride(from: 90.0, to: 180, by: 1).map { EyeSample(time: $0 / 30, face: EyeTestData.face()) }
        analysis.add(frames, over: span)
        let plan = EyeGazePlan.make(analysis)
        // Its window (2 s and a bit either side) reaches outside what's analyzed.
        #expect(plan.frame(at: 3.2, strength: 1) == nil)
        #expect(plan.holds[plan.index(at: 3.2) ?? 0] == .notAnalyzed)
    }

    @Test func eachFrameReadsTheSampleOfTheFrameShown() {
        let plan = EyeGazePlan.make(EyeTestData.analysis())
        // Between two frames (slowed down): the earlier one; a rounding of a millisecond: the frame itself.
        #expect(plan.index(at: 5.0 + 0.6 / 30) == plan.index(at: 5.0))
        #expect(plan.index(at: 5.0 + 1.0 / 30 - 0.001) == plan.index(at: 5.0 + 1.0 / 30))
        // Past the end of the analyzed frames: nothing.
        #expect(plan.index(at: 30) == nil)
    }

    @Test func theSameAnalysisGivesTheSameDecisions() {
        let analysis = EyeTestData.analysis { time in EyeTestData.face(opening: (2..<2.1).contains(time) ? 0.02 : 0.3) }
        let first = EyeGazePlan.make(analysis), second = EyeGazePlan.make(analysis)
        #expect(first.frames == second.frames)
        #expect(first.holds == second.holds)
    }

    @Test func theSummaryCountsWhatTheEditPlays() {
        let plan = EyeGazePlan.make(EyeTestData.analysis { time in time < 5 ? nil : EyeTestData.face() })
        let early = plan.summary(in: [TimeSpan(start: 0, end: 4)])
        #expect(early.corrected == 0)
        #expect(early.mainHold == .noFace)
        #expect(plan.summary(in: [TimeSpan(start: 6, end: 9)]).corrected == 1)
    }

    @Test func pointsAreSmoothedWithoutLaggingARealMove() {
        // A point shaking ±2 px around 100, then moving to 200 at frame 60.
        let times = (0..<120).map { Double($0) / 30 }
        let values = (0..<120).map { index -> [Double] in [(index < 60 ? 100 : 200) + (index.isMultiple(of: 2) ? 2 : -2)] }
        let smoothed = EyeTrackSmoother.smooth(values, times: times, cutoff: EyeContactCalibration.smoothingCutoff, speed: EyeContactCalibration.smoothingSpeed)
        // At the worst frequency (a shake every frame) it's more than halved; slower drift is smoothed far more.
        let still = smoothed[20..<50].map { $0[0] }
        #expect((still.max() ?? 0) - (still.min() ?? 0) < 2)
        // Settled within a few frames either side of the move (no lag: it runs both ways).
        #expect(abs(smoothed[70][0] - 200) < 3)
        #expect(abs(smoothed[50][0] - 100) < 3)
    }
}
