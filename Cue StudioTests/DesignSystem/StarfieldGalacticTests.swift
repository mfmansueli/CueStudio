//
//  StarfieldGalacticTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The Galactic sky (Starry sky › Galactic): its three nebulae, the Milky Way band and the spaceship that crosses where Lively has the comet.
@Suite("StarfieldMath · Galactic")
struct StarfieldGalacticTests {
    private let screen = CGSize(width: 390, height: 844)

    // MARK: - Nebulae

    @Test func thereAreThreeNebulaeOneInEachColourAndTheyAreAlwaysTheSame() {
        let nebulae = StarfieldMath.galacticNebulae(seed: 27)
        #expect(nebulae.map(\.hue) == [.blue, .magenta, .teal])
        #expect(nebulae == StarfieldMath.galacticNebulae(seed: 27))
        #expect(nebulae != StarfieldMath.galacticNebulae(seed: 28))
    }

    @Test func theNebulaeStayWithinTheirPlacesAndAreFaint() {
        for seed in [27, 7, 99] as [UInt64] {
            for nebula in StarfieldMath.galacticNebulae(seed: seed) {
                #expect(StarfieldMath.galacticNebulaOpacity.contains(nebula.opacity))
                #expect((280...400).contains(nebula.diameter) && (30...40).contains(nebula.period))
                #expect((0.05...0.92).contains(nebula.x) && (0.05...0.9).contains(nebula.y))
            }
        }
    }

    @Test func theVioletNebulaeOfCalmAndLivelyAreUntouched() {
        let nebulae = StarfieldMath.nebulae(seed: 27)
        #expect(nebulae.count == 2 && nebulae.allSatisfy { $0.hue == .violet })
    }

    // MARK: - The Milky Way

    @Test func theBandsDustIsDeterministicAndInsideTheBand() {
        let dust = StarfieldMath.bandStars(seed: 27)
        #expect(dust.count == StarfieldMath.bandStarCount)
        #expect(dust == StarfieldMath.bandStars(seed: 27))
        #expect(dust.allSatisfy { (-0.5...0.5).contains($0.along) && (-1...1).contains($0.across) })
        #expect(dust.allSatisfy { (0.5...1.2).contains($0.size) && (0.25...0.7).contains($0.opacity) })
        // Most grains are near the middle of the band.
        #expect(dust.filter { abs($0.across) < 0.5 }.count > dust.count / 2)
    }

    @Test func theBandDriftsAcrossItselfAndBackWithinItsRange() {
        #expect(StarfieldMath.bandOffset(at: 0) == 0)
        for step in 0..<200 {
            let offset = StarfieldMath.bandOffset(at: Double(step) * 0.9)
            #expect(abs(offset) <= StarfieldMath.bandDrift + 0.0001)
        }
        #expect(abs(StarfieldMath.bandOffset(at: StarfieldMath.bandPeriod)) < 0.0001)
    }

    // MARK: - The spaceship

    @Test func noSpaceshipBeforeTheFirstAndOneAfterIt() {
        #expect(StarfieldMath.spaceship(at: 0, size: screen, seed: 27) == nil)
        #expect(StarfieldMath.spaceship(at: StarfieldMath.firstSpaceshipDelay - 0.1, size: screen, seed: 27) == nil)
        #expect(StarfieldMath.spaceship(at: StarfieldMath.firstSpaceshipDelay + 1, size: screen, seed: 27) != nil)
    }

    @Test func aSpaceshipCrossesInSixteenToTwentyTwoSecondsAndThenTheSkyIsEmptyAgain() {
        let begins = StarfieldMath.firstSpaceshipDelay
        #expect(StarfieldMath.spaceship(at: begins + StarfieldMath.spaceshipDuration.lowerBound - 0.1, size: screen, seed: 27) != nil)
        #expect(StarfieldMath.spaceship(at: begins + StarfieldMath.spaceshipDuration.upperBound + 0.1, size: screen, seed: 27) == nil)
        #expect(StarfieldMath.spaceship(at: begins + 60, size: screen, seed: 27) == nil)
    }

    /// The owner's call (6/10/2026): the sky sits behind a screen full of information, so the ship is rare, small and slow.
    @Test func theSpaceshipIsRareSmallAndSlow() {
        #expect(StarfieldMath.firstSpaceshipDelay >= 90)
        #expect(StarfieldMath.spaceshipInterval.lowerBound >= 240)
        #expect(StarfieldMath.spaceshipLength.upperBound <= 22)
        #expect(StarfieldMath.spaceshipDuration.lowerBound >= 16)
        // In the first ten minutes there are at most three of them.
        var count = 0
        while StarfieldMath.spaceshipBegin(index: count, seed: 27) < 600 { count += 1 }
        #expect(count <= 3)
    }

    @Test func theNextOnesComeEveryFourToSevenMinutes() {
        let first = StarfieldMath.spaceshipBegin(index: 0, seed: 27)
        #expect(first == StarfieldMath.firstSpaceshipDelay)
        var previous = first
        for index in 1..<8 {
            let begin = StarfieldMath.spaceshipBegin(index: index, seed: 27)
            #expect(StarfieldMath.spaceshipInterval.contains(begin - previous), "\(index)")
            // The ship is in the sky right then, and gone just before it leaves.
            #expect(StarfieldMath.spaceship(at: begin + 0.5, size: screen, seed: 27) != nil, "\(index)")
            #expect(StarfieldMath.spaceship(at: begin - 1, size: screen, seed: 27) == nil, "\(index)")
            previous = begin
        }
    }

    @Test func aSpaceshipEntersOffOneEdgeAndLeavesOffTheOther() {
        for index in 0..<10 {
            let begin = StarfieldMath.spaceshipBegin(index: index, seed: 27)
            let start = StarfieldMath.spaceship(at: begin + 0.01, size: screen, seed: 27)
            let end = StarfieldMath.spaceship(at: begin + StarfieldMath.spaceshipDuration.lowerBound - 0.1, size: screen, seed: 27)
            guard let ship = start else {
                Issue.record("no spaceship at the start of flight \(index)")
                continue
            }
            #expect(ship.position.x < 0 || ship.position.x > screen.width, "enters off an edge (\(index))")
            #expect(ship.start.x == -60 || ship.start.x == screen.width + 60)
            #expect(ship.end.x == (ship.start.x < 0 ? screen.width + 60 : -60))
            #expect(end != nil)
            // Never below the middle of the sky, where the content sits.
            #expect((0...screen.height * 0.62).contains(ship.start.y) && (0...screen.height * 0.62).contains(ship.end.y))
            #expect(StarfieldMath.spaceshipLength.contains(Double(ship.length)))
        }
    }

    @Test func theNoseFollowsTheFlightAndTheShipFadesOnlyAtTheVeryEnds() {
        let left = StarfieldMath.Spaceship(
            time: 0.5, duration: 18, start: CGPoint(x: -60, y: 100), control: CGPoint(x: 195, y: 100), end: CGPoint(x: 450, y: 100), length: 20
        )
        #expect(abs(left.heading) < 0.0001)
        #expect(left.opacity == 1)
        let right = StarfieldMath.Spaceship(
            time: 0.5, duration: 18, start: CGPoint(x: 450, y: 100), control: CGPoint(x: 195, y: 100), end: CGPoint(x: -60, y: 100), length: 20
        )
        #expect(abs(abs(right.heading) - .pi) < 0.0001)
        let entering = StarfieldMath.Spaceship(time: 0.02, duration: 18, start: left.start, control: left.control, end: left.end, length: 20)
        #expect(entering.opacity > 0 && entering.opacity < 1)
        #expect(StarfieldMath.Spaceship(time: 0, duration: 18, start: left.start, control: left.control, end: left.end, length: 20).opacity == 0)
    }

    @Test func theScheduleIsTheSameEveryTimeItIsAsked() {
        let time = StarfieldMath.firstSpaceshipDelay + 4
        #expect(StarfieldMath.spaceship(at: time, size: screen, seed: 27) == StarfieldMath.spaceship(at: time, size: screen, seed: 27))
    }

    @Test func theTrailFollowsThePathTheShipFlewAndNotAStraightLine() {
        let ship = StarfieldMath.Spaceship(
            time: 0.6, duration: 20, start: CGPoint(x: -60, y: 300), control: CGPoint(x: 195, y: 100), end: CGPoint(x: 450, y: 300), length: 20
        )
        #expect(ship.position(atTime: ship.time) == ship.position)
        // Behind the ship, at the start of the trail, the path is still on the curve: above the straight line between its two ends.
        let behind = ship.position(atTime: ship.time - StarfieldMath.spaceshipTrailSeconds / ship.duration)
        #expect(behind.x < ship.position.x)
        #expect(behind.y < 300)
        // The trail reaches back about 125 pt.
        let reach = hypot(ship.position.x - behind.x, ship.position.y - behind.y)
        #expect((80...180).contains(reach), "\(reach)")
    }

    // MARK: - The stars' strength

    @Test func theAppsStarsAreMoreDelicateThanTheBoardsOnes() {
        #expect(StarfieldMath.delicateLook.opacity < 1 && StarfieldMath.delicateLook.size < 1)
        #expect(StarfieldMath.boardLook == StarfieldMath.StarLook(opacity: 1, size: 1))
        // Not so faint that the brightest layer disappears: a drifting star never drops under 15%.
        let faintest = StarfieldMath.layers.map { $0.opacity.lowerBound * StarfieldMath.delicateLook.opacity }.min() ?? 0
        #expect(faintest >= 0.15)
    }
}
