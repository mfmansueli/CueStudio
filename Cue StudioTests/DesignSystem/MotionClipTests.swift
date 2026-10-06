//
//  MotionClipTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

/// The engine that plays the boards' motion: easing text, sampling between keyframes, holding, delays, loops, and the baked file.
struct MotionClipTests {
    private func frames(_ json: String) throws -> [MotionFrame] {
        try JSONDecoder().decode([MotionFrame].self, from: Data(json.utf8))
    }

    private func clip(frames json: String, duration: Double = 2, delay: Double = 0, easing: String = "\"linear\"", loops: Bool = false) throws -> MotionClip {
        let animation = try JSONDecoder().decode(
            MotionAnimation.self,
            from: Data(#"{"kf":"k","duration":\#(duration),"delay":\#(delay),"easing":\#(easing),"loops":\#(loops)}"#.utf8)
        )
        return MotionClip(name: "test", layers: ["L1": [animation]], frames: ["k": try frames(json)])
    }

    // MARK: - Easing

    @Test func easingReadsCubicBezierAsNumbersAndAsCSSText() throws {
        let numbers = try JSONDecoder().decode(MotionEasing.self, from: Data("[0.16,1,0.3,1]".utf8))
        let text = MotionEasing.parse("cubic-bezier(.16,1,.3,1)")
        #expect(abs(numbers.value(at: 0.3) - text.value(at: 0.3)) < 0.0001)
        #expect(numbers.value(at: 0.3) > 0.7)
    }

    @Test func easingKnowsTheCSSKeywordsAndSteps() {
        #expect(MotionEasing.parse("linear").value(at: 0.4) == 0.4)
        #expect(MotionEasing.parse("ease-out").value(at: 0.5) > 0.5)
        #expect(MotionEasing.parse("ease-in-out").value(at: 0.5) == 0.5)
        #expect(MotionEasing.parse("steps(4,end)").value(at: 0.6) == 0.5)
    }

    // MARK: - Sampling

    @Test func aChannelHoldsBeforeItsFirstKeyframeAndAfterItsLast() throws {
        let clip = try clip(frames: #"[{"t":0.5,"opacity":0.2},{"t":1.5,"opacity":0.8}]"#)
        #expect(clip.pose(of: "L1", at: 0).opacity == 0.2)
        #expect(clip.pose(of: "L1", at: 2).opacity == 0.8)
    }

    @Test func aChannelInterpolatesBetweenTheKeyframesThatSetIt() throws {
        let clip = try clip(frames: #"[{"t":0,"opacity":0,"tx":0},{"t":1,"opacity":1},{"t":2,"opacity":1,"tx":10}]"#)
        // `tx` is only set at 0 and 2, so it runs across the whole stretch.
        #expect(abs(clip.pose(of: "L1", at: 1).tx - 5) < 0.0001)
        #expect(abs(clip.pose(of: "L1", at: 0.5).opacity - 0.5) < 0.0001)
    }

    @Test func aKeyframesOwnEasingShapesTheStretchThatStartsThere() throws {
        let clip = try clip(frames: #"[{"t":0,"opacity":0,"easing":"ease-out"},{"t":1,"opacity":1}]"#, duration: 1)
        #expect(clip.pose(of: "L1", at: 0.25).opacity > 0.25)
    }

    @Test func theAnimationWaitsForItsDelay() throws {
        let clip = try clip(frames: #"[{"t":0,"opacity":0},{"t":1,"opacity":1}]"#, duration: 1, delay: 2)
        #expect(clip.pose(of: "L1", at: 1).opacity == 0)
        #expect(abs(clip.pose(of: "L1", at: 2.5).opacity - 0.5) < 0.0001)
        #expect(clip.pose(of: "L1", at: 9).opacity == 1)
    }

    @Test func aLoopRepeatsOnlyWhenAskedTo() throws {
        let clip = try clip(frames: #"[{"t":0,"opacity":0},{"t":1,"opacity":1}]"#, duration: 1, loops: true)
        #expect(clip.pose(of: "L1", at: 1.25).opacity == 1)
        #expect(abs(clip.pose(of: "L1", at: 1.25, loops: true).opacity - 0.25) < 0.0001)
    }

    @Test func aLayerTheBoardDoesNotAnimateStaysAtRest() throws {
        let clip = try clip(frames: #"[{"t":0,"opacity":0},{"t":1,"opacity":1}]"#)
        #expect(!clip.has("L2"))
        #expect(clip.pose(of: "L2", at: 1).opacity == 1)
    }

    @Test func colourFadesKeepTheirHueWhenTheyFadeToTransparent() throws {
        let clip = try clip(frames: #"[{"t":0,"glow":[255,214,10,0],"glowR":0},{"t":1,"glow":[255,214,10,1],"glowR":10}]"#, duration: 1)
        let pose = clip.pose(of: "L1", at: 0.5)
        #expect(abs(pose.glowRadius - 5) < 0.0001)
        let resolved = pose.glow.map { UIColor($0) }
        var (red, green, alpha): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        resolved?.getRed(&red, green: &green, blue: nil, alpha: &alpha)
        #expect(abs(red - 1) < 0.01 && abs(green - 214.0 / 255) < 0.01 && abs(alpha - 0.5) < 0.01)
    }

    // MARK: - The baked file

    @Test func theBakedFileHoldsTheOnboardingBoards() {
        for board in ["1.1_welcome", "1.2_topics", "1.3_voyage", "1.4_first-message", "1.5_permissions", "1.6_practice", "1.7_first-star"] {
            let clip = MotionLibrary.clip(board)
            #expect(clip.has("L1") || clip.has("L2"), "\(board) has no animated layers")
        }
    }

    @Test func theWelcomeHaloGrowsFromNothingToFull() {
        let clip = MotionLibrary.clip("1.1_welcome")
        let before = clip.pose(of: "L2", at: 0.5)
        let after = clip.pose(of: "L2", at: 3.5)
        #expect(before.opacity == 0 && abs(before.sx - 0.6) < 0.0001)
        #expect(after.opacity == 1 && after.sx == 1)
    }

    @Test func aSparkFliesOutAlongItsOwnAngle() {
        // 1.3 L58: a spark whose `--a` is 10°, starting 2 pt out and ending far further along the same ray.
        let clip = MotionLibrary.clip("1.3_voyage")
        let start = clip.pose(of: "L58", at: 0)
        let end = clip.pose(of: "L58", at: 6.4)
        #expect(start.rot == 10 && end.rot == 10)
        #expect(hypot(end.tx, end.ty) > hypot(start.tx, start.ty) * 3)
        #expect(abs(atan2(end.ty, end.tx) * 180 / .pi - 10) < 0.01)
    }
}
