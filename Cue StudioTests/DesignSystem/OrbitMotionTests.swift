//
//  OrbitMotionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A body on a flattened orbit: the same lap time, a little faster, bigger and brighter in front, and never a jump.
@Suite("OrbitMotion")
struct OrbitMotionTests {
    @Test func aLapTakesTheSameTimeAndNeverGoesBack() {
        let means = stride(from: 0.0, through: 4 * .pi, by: 0.01)
        let angles = means.map(OrbitMotion.angle(mean:))
        #expect(zip(angles, angles.dropFirst()).allSatisfy { $1 > $0 })
        #expect(abs(OrbitMotion.angle(mean: 2 * .pi) - OrbitMotion.angle(mean: 0) - 2 * .pi) < 1e-9)
    }

    @Test func itIsFasterInFrontThanBehind() {
        func pace(at mean: Double) -> Double { (OrbitMotion.angle(mean: mean + 0.001) - OrbitMotion.angle(mean: mean)) / 0.001 }
        #expect(pace(at: .pi / 2) > pace(at: 3 * .pi / 2))
        #expect(abs(pace(at: .pi / 2) - (1 + OrbitMotion.swing)) < 0.01)
    }

    @Test func itIsBiggerAndBrighterInFront() {
        #expect(OrbitMotion.scale(at: .pi / 2) > OrbitMotion.scale(at: 3 * .pi / 2))
        #expect(OrbitMotion.light(at: .pi / 2) == 1)
        #expect(abs(OrbitMotion.light(at: 3 * .pi / 2) - 0.8) < 1e-9)
        #expect(abs(OrbitMotion.scale(at: .pi / 2) - 1.1) < 1e-9)
    }
}
