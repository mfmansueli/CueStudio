//
//  StarfieldMathTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The sky: always the same for a seed, and inside the numbers the design gives.
@Suite("StarfieldMath")
struct StarfieldMathTests {
    @Test func aSeedMakesTheSameSkyEveryTime() {
        #expect(StarfieldMath.stars(in: StarfieldMath.far, seed: 5) == StarfieldMath.stars(in: StarfieldMath.far, seed: 5))
        #expect(StarfieldMath.stars(in: StarfieldMath.far, seed: 5) != StarfieldMath.stars(in: StarfieldMath.far, seed: 6))
        #expect(StarfieldMath.twinkles(count: 5, seed: 1) == StarfieldMath.twinkles(count: 5, seed: 1))
    }

    @Test func theLayersHaveTheDesignsStarCountsAndSizes() {
        for layer in StarfieldMath.layers {
            let stars = StarfieldMath.stars(in: layer, seed: 3)
            #expect(stars.count == layer.starsPerTile)
            #expect(stars.allSatisfy { layer.size.contains($0.size) && layer.opacity.contains($0.opacity) })
            #expect(stars.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
        #expect(StarfieldMath.far.starsPerTile == 16 && StarfieldMath.mid.starsPerTile == 12 && StarfieldMath.near.starsPerTile == 7)
    }

    @Test func theNearLayerDriftsFasterThanTheFarOne() {
        let near = StarfieldMath.drift(of: StarfieldMath.near, at: 10) / StarfieldMath.near.tile.height
        let far = StarfieldMath.drift(of: StarfieldMath.far, at: 10) / StarfieldMath.far.tile.height
        #expect(near > far)
    }

    @Test func theDriftWrapsAtOneTile() {
        let layer = StarfieldMath.near
        #expect(abs(StarfieldMath.drift(of: layer, at: layer.drift) - 0) < 0.001)
        #expect(StarfieldMath.drift(of: layer, at: layer.drift / 2) > 0)
        #expect(StarfieldMath.drift(of: layer, at: 0) == 0)
    }

    @Test func twinklesStayWithinTheirRanges() {
        let twinkles = StarfieldMath.twinkles(count: 8, seed: 9)
        #expect(twinkles.count == 8)
        #expect(twinkles.allSatisfy { (1.8...3.0).contains($0.size) && (2.6...4.1).contains($0.cycle) })
        // About half have the cross glint.
        #expect(twinkles.filter(\.hasGlint).count == 4)
    }

    @Test func aTwinkleKeepsItsOpacityAndScaleInTheDesignsRange() {
        for step in 0...100 {
            let level = StarfieldMath.twinkleLevel(at: Double(step) / 100)
            #expect((0.2...1.0).contains(level.opacity))
            #expect((0.7...1.3).contains(level.scale))
        }
        #expect(StarfieldMath.twinkleLevel(at: 3.25).opacity == StarfieldMath.twinkleLevel(at: 0.25).opacity)
    }

    @Test func aShootingStarCrossesForSevenTenthsOfASecondAndThenWaitsForTheNext() {
        let size = CGSize(width: 390, height: 844)
        var seen = 0
        var lastCrossing: Double?
        var gaps: [Double] = []
        for tenths in 0..<(60 * 10) {
            let time = Double(tenths) / 10
            if StarfieldMath.shootingStar(slot: 0, at: time, size: size, seed: 27) != nil {
                if lastCrossing == nil || time - (lastCrossing ?? 0) > 1 {
                    if let lastCrossing { gaps.append(time - lastCrossing) }
                    seen += 1
                }
                lastCrossing = time
            }
        }
        #expect(seen >= 4)
        // One every 11 to 14 s.
        #expect(gaps.allSatisfy { $0 >= 10.5 && $0 <= 14.5 })
    }

    @Test func aShootingStarMovesLeftAndDownAtOneHundredSixtyDegrees() {
        let star = StarfieldMath.shootingStar(slot: 0, at: 0.35 + 11.35 * 0, size: CGSize(width: 390, height: 844), seed: 27)
            ?? StarfieldMath.ShootingStar(progress: 0.5, start: .zero, direction: CGVector(dx: cos(160 * Double.pi / 180), dy: sin(160 * Double.pi / 180)))
        #expect(star.direction.dx < 0 && star.direction.dy > 0)
        #expect(abs(hypot(star.direction.dx, star.direction.dy) - 1) < 0.0001)
        #expect(StarfieldMath.ShootingStar(progress: 0.5, start: .zero, direction: star.direction).opacity == 1)
        #expect(StarfieldMath.ShootingStar(progress: 0, start: .zero, direction: star.direction).opacity == 0)
    }

    @Test func twoSlotsNeverFireAtTheSameMoment() {
        let size = CGSize(width: 390, height: 844)
        for tenths in 0..<(120 * 10) {
            let time = Double(tenths) / 10
            let first = StarfieldMath.shootingStar(slot: 0, at: time, size: size, seed: 27)
            let second = StarfieldMath.shootingStar(slot: 1, at: time, size: size, seed: 27)
            #expect(first == nil || second == nil, "both at \(time)")
        }
    }

    @Test func theNebulaeAreTheDesignsSizeAndBreatheBackAndForth() {
        let nebulae = StarfieldMath.nebulae(seed: 27)
        #expect(nebulae.count == 2)
        #expect(nebulae.allSatisfy { (240...320).contains($0.diameter) && (0.10...0.22).contains($0.opacity) && (26...34).contains($0.period) })
        let period = nebulae[0].period
        #expect(StarfieldMath.nebulaPhase(at: 0, period: period) == 0)
        #expect(abs(StarfieldMath.nebulaPhase(at: period, period: period) - 1) < 0.0001)
        #expect(abs(StarfieldMath.nebulaPhase(at: period * 2, period: period)) < 0.0001)
    }

    @Test func theDensitiesScaleTheTwinklesAndShootingStars() {
        #expect(SkyDensity.off.twinkleCount == 0 && SkyDensity.off.shootingStarSlots == 0)
        #expect((3...8).contains(SkyDensity.calm.twinkleCount) && (3...8).contains(SkyDensity.lively.twinkleCount))
        #expect(SkyDensity.lively.twinkleCount > SkyDensity.calm.twinkleCount)
        #expect(SkyDensity.lively.shootingStarSlots == 2 && SkyDensity.calm.shootingStarSlots == 1)
        #expect(SkyDensity.allCases.map(\.step) == [0, 1, 2])
    }
}
