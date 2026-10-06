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
        let twinkles = StarfieldMath.twinkles(count: 14, seed: 9)
        #expect(twinkles.count == 14)
        // A 7 s cycle for every star, each starting 0 to 5.2 s in.
        #expect(twinkles.allSatisfy { StarfieldMath.twinkleSize.contains($0.size) && $0.cycle == 7 && (0...(5.2 / 7)).contains($0.phase) })
        // About half have the cross glint.
        #expect(twinkles.filter(\.hasGlint).count == 7)
    }

    @Test func aTwinkleFollowsTheMotionSpecsKeyframes() {
        let start = StarfieldMath.twinkleLevel(at: 0)
        #expect(abs(start.opacity - 0.16) < 0.001 && abs(start.scale - 0.75) < 0.001)
        let peak = StarfieldMath.twinkleLevel(at: 0.45)
        #expect(abs(peak.opacity - 0.75) < 0.001 && abs(peak.scale - 1) < 0.001)
        #expect(abs(StarfieldMath.twinkleLevel(at: 0.60).opacity - 0.58) < 0.001)
        for step in 0...100 {
            let level = StarfieldMath.twinkleLevel(at: Double(step) / 100)
            #expect((0.16...0.75).contains(level.opacity))
            #expect((0.75...1.0).contains(level.scale))
        }
        #expect(abs(StarfieldMath.twinkleLevel(at: 3.25).opacity - StarfieldMath.twinkleLevel(at: 0.25).opacity) < 0.0001)
    }

    // MARK: - The comet

    private let screen = CGSize(width: 390, height: 844)

    /// The seconds after launch at which the comet is on screen, in steps of a tenth.
    private func crossings(until seconds: Int, seed: UInt64 = 27) -> [Double] {
        (0..<(seconds * 10)).map { Double($0) / 10 }.filter { StarfieldMath.comet(at: $0, size: screen, seed: seed) != nil }
    }

    @Test func noCometBeforeTheFirstOneAt25Seconds() {
        #expect(crossings(until: 24).isEmpty)
        let first = crossings(until: 30)
        #expect(first.first.map { $0 >= 25 && $0 <= 25.3 } == true)
    }

    @Test func aCometTakesBetween1_7And2_4SecondsAndTheNextComesEvery105To135() {
        let seen = crossings(until: 700)
        #expect(!seen.isEmpty)
        // Group the tenths of one crossing; each lasts 1.7 to 2.4 s.
        var groups: [[Double]] = []
        for time in seen {
            if let last = groups.last?.last, time - last < 1 { groups[groups.count - 1].append(time) } else { groups.append([time]) }
        }
        #expect(groups.count >= 5)
        for group in groups {
            let length = (group.last ?? 0) - (group.first ?? 0)
            #expect(length >= 1.5 && length <= 2.4, "\(length)")
        }
        let gaps = zip(groups, groups.dropFirst()).map { ($1.first ?? 0) - ($0.first ?? 0) }
        #expect(gaps.allSatisfy { $0 >= 104 && $0 <= 136.4 })
    }

    @Test func aCometGoesAnyWayItLikesButTravelsTheDesignsDistanceWithATail() {
        var directions = Set<Int>()
        var index = 0
        for seed in 1...40 {
            guard let comet = firstComet(seed: UInt64(seed)) else { continue }
            #expect((520...680).contains(Double(comet.distance)) && (140...210).contains(Double(comet.tail)))
            #expect(abs(hypot(comet.direction.dx, comet.direction.dy) - 1) < 0.0001)
            directions.insert(Int(atan2(comet.direction.dy, comet.direction.dx) * 180 / .pi / 45))
            index += 1
        }
        #expect(index > 20 && directions.count >= 4, "any direction")
    }

    /// The first comet of a sky: it comes at 25 s, between 25 and 27.4.
    private func firstComet(seed: UInt64) -> StarfieldMath.Comet? {
        (250..<290).lazy.compactMap { StarfieldMath.comet(at: Double($0) / 10, size: screen, seed: seed) }.first
    }

    @Test func theCometFadesInReachesFullAndFadesOut() {
        func comet(_ time: Double) -> StarfieldMath.Comet {
            StarfieldMath.Comet(time: time, start: .zero, direction: CGVector(dx: 1, dy: 0), distance: 600, tail: 170)
        }
        #expect(comet(0).opacity == 0)
        #expect(abs(comet(0.12).opacity - 1) < 0.0001)
        #expect(abs(comet(0.72).opacity - 0.9) < 0.0001)
        #expect(abs(comet(1).opacity) < 0.0001)
        #expect(comet(0).progress == 0 && abs(comet(1).progress - 1) < 0.0001)
        // `cubic-bezier(.3,.1,.45,1)`: a slow start, then it settles; always forward.
        var previous = -1.0
        for step in 0...20 {
            let value = comet(Double(step) / 20).progress
            #expect(value >= previous)
            previous = value
        }
    }

    @Test func theCubicBezierIsTheCSSOne() {
        // The linear curve and the standard ease-in-out at its middle.
        #expect(abs(StarfieldMath.cubicBezier(0, 0, 1, 1, at: 0.3) - 0.3) < 0.001)
        #expect(abs(StarfieldMath.cubicBezier(0.42, 0, 0.58, 1, at: 0.5) - 0.5) < 0.001)
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

    @Test func onlyLivelyHasTheTwinklesAndTheComet() {
        #expect(SkyDensity.off.twinkleCount == 0 && !SkyDensity.off.hasComet)
        #expect(SkyDensity.calm.twinkleCount == 0 && !SkyDensity.calm.hasComet)
        #expect(SkyDensity.lively.twinkleCount == 14 && SkyDensity.lively.hasComet)
        #expect(SkyDensity.galactic.twinkleCount == 14 && !SkyDensity.galactic.hasComet)
        #expect(SkyDensity.allCases.map(\.step) == [0, 1, 2, 3])
    }

    @Test func theTwinklesAreSmallerThanTheDesignsOriginalOnes() {
        #expect(StarfieldMath.twinkleSize.upperBound < 3.0 && StarfieldMath.twinkleSize.lowerBound < 1.8)
        #expect(StarfieldMath.glintHalfLength < 8)
        // Smaller, but where they are and when they light does not change.
        let small = StarfieldMath.twinkles(count: 14, seed: 27)
        #expect(small.allSatisfy { (0.06...0.94).contains($0.x) && (0.05...0.9).contains($0.y) })
    }
}
