//
//  ProOpeningScriptTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The Pro opening (09, "11.4 · Pro paywall — opening moment", and the owner's finish): 42 streaks, a star that flies up to the planet's place,
/// the planet born there with its orbits drawing round it, and the content fading up.
@MainActor
@Suite("Pro opening")
struct ProOpeningScriptTests {
    @Test func theOpeningsLightLastsThreeSecondsAndIsTappableFromOnePointFour() {
        #expect(ProOpeningScript.duration == 3)
        #expect(ProOpeningScript.tappableFrom == 1.4)
        #expect(ProOpeningScript.streaks.count == 42)
    }

    @Test func theStreaksAreSixtyToTwoHundredPointsAndStartWithinTwoTenthsAndAHalf() {
        let lengths = ProOpeningScript.streaks.map(\.length)
        #expect(lengths.allSatisfy { (60...200).contains($0) })
        #expect(ProOpeningScript.streaks.map(\.delay).allSatisfy { (0...0.24).contains($0) })
        #expect(ProOpeningScript.streaks.map(\.delay) == ProOpeningScript.streaks.map(\.delay).sorted())
    }

    @Test func aStreakComesInFromTheEdgeToTheCentreInNinetyTenthsOfASecond() throws {
        let streak = try #require(ProOpeningScript.streaks.first)
        #expect(ProOpeningScript.progress(of: streak, at: 0) == 0)
        #expect(ProOpeningScript.progress(of: streak, at: 0.9 + streak.delay) == 1)
        let middle = ProOpeningScript.progress(of: streak, at: 0.45 + streak.delay)
        #expect(middle > 0 && middle < 0.5, "the curve starts slowly (0.5, 0, 0.8, 0.4)")
    }

    @Test func theCoreGrowsFromTwentyToOneSixtyPercentBetweenSevenTenthsAndOnePointFour() {
        #expect(ProOpeningScript.core.pose(at: 0.7).scale == 0.2)
        #expect(ProOpeningScript.core.pose(at: 1.4).scale == 1.6)
        #expect(ProOpeningScript.core.pose(at: 0.5).opacity == 0)
    }

    @Test func theStarFliesUpToThePlanetAndGoesOutIntoIt() {
        // 1.4–1.5 s it waits at ×1.6 at the focus; it reaches the planet's place at 2.1 s, smaller, and is gone at 2.18 s.
        #expect(ProOpeningScript.core.pose(at: 1.45).y == 0 && ProOpeningScript.core.pose(at: 1.45).scale == 1.6)
        #expect(ProOpeningScript.core.pose(at: 1.8).y > 0 && ProOpeningScript.core.pose(at: 1.8).y < 1)
        #expect(ProOpeningScript.core.pose(at: 2.1).y == 1 && ProOpeningScript.core.pose(at: 2.1).scale == 0.9)
        #expect(ProOpeningScript.core.pose(at: 2.18).opacity == 0)
        // It bows out to the right on the way and ends on the planet.
        let focus = CGPoint(x: 195, y: 375)
        let planet = CGPoint(x: 195, y: 150)
        #expect(ProOpeningScript.flight(from: focus, to: planet, progress: 0.5).x > 195)
        #expect(ProOpeningScript.flight(from: focus, to: planet, progress: 1).y == 150)
    }

    @Test func theRingOfLightClosesInAsThePlanetIsBornWhiteHot() {
        #expect(ProOpeningScript.gather.pose(at: 1.97).scale > ProOpeningScript.gather.pose(at: 2.1).scale)
        #expect(ProOpeningScript.gather.pose(at: 2.14).scale == 1)
        #expect(ProOpeningScript.whiteHot.pose(at: 2.16).opacity == 1 && ProOpeningScript.whiteHot.pose(at: 2.95).opacity == 0)
        #expect(ProOpeningScript.orbitsDraw.pose(at: 2.3).scale == 0 && ProOpeningScript.orbitsDraw.pose(at: ProOpeningScript.settled).scale == 1)
        #expect(ProOpeningScript.travellers.pose(at: ProOpeningScript.settled).opacity == 1)
    }

    @Test func nothingOfThePlanetsBirthShowsBeforeTheStarArrives() {
        for second in stride(from: 0.0, to: 2.1, by: 0.05) {
            #expect(ProOpeningScript.birthSparks.pose(at: second).opacity == 0, "the sparks at \(second) s")
            #expect(ProOpeningScript.gather.pose(at: second).opacity < 0.9 || second > 1.9, "the ring at \(second) s")
            #expect(ProOpeningScript.birthBloom.pose(at: second).opacity == 0, "the bloom at \(second) s")
            #expect(ProOpeningScript.whiteHot.pose(at: second).opacity == 0, "the white planet at \(second) s")
            #expect(ProOpeningScript.planet.pose(at: second).opacity == 0, "the planet at \(second) s")
            #expect(ProOpeningScript.travellers.pose(at: second).opacity == 0, "the small planets at \(second) s")
        }
        #expect(ProOpeningScript.gather.pose(at: 1.5).opacity == 0)
        #expect(ProOpeningScript.orbitsDraw.pose(at: 2.0).scale == 0)
    }

    @Test func theRingExpandsFromFortyPercentToFourteenTimesAndFades() {
        #expect(ProOpeningScript.shockwave.pose(at: 1.25).scale == 0.4)
        #expect(ProOpeningScript.shockwave.pose(at: 2.35).scale == 14)
        #expect(ProOpeningScript.shockwave.pose(at: 2.4).opacity == 0)
    }

    @Test func thePlanetIsBornPastItsSizeThenSettles() {
        // It is born as the star reaches it (2.12 s), springs to ×1.08 and rests at 2.85 s.
        #expect(ProOpeningScript.planet.pose(at: 2.12).scale == 0.3)
        #expect(ProOpeningScript.planet.pose(at: 2.55).scale == 1.08)
        #expect(ProOpeningScript.planet.pose(at: ProOpeningScript.settled).scale == 1)
        #expect(ProOpeningScript.planet.pose(at: 1.5).opacity == 0)
        #expect(ProOpeningScript.settled > ProOpeningScript.duration)
    }

    @Test func theContentComesUpSeventyMillisecondsApartAndIsInPlaceAtTheEnd() {
        let first = ProOpeningScript.reveal(0)
        let second = ProOpeningScript.reveal(1)
        #expect(first.pose(at: 1.3).opacity == 0 && first.pose(at: 1.3).y == 18)
        #expect(abs((second.keyframes[0].time - first.keyframes[0].time) - 0.07) < 0.0001)
        for index in 0...8 {
            let pose = ProOpeningScript.reveal(index).pose(at: ProOpeningScript.settled)
            #expect(pose.opacity == 1 && pose.y == 0 && pose.blur == 0)
        }
    }

    @Test func theHapticsAreSoftAtTheIgnitionAndSuccessWhenThePlanetIsBorn() {
        #expect(ProOpeningScript.ignitionBeat == 1.25)
        #expect(ProOpeningScript.landing == 2.16)
        #expect(ProOpeningScript.landing < ProOpeningScript.duration)
    }
}
