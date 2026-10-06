//
//  ProOpeningScriptTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The Pro opening (09, "11.4 · Pro paywall — opening moment"): 2.4 s, 42 streaks, a core, a ring, the planet and the content fading up.
@MainActor
@Suite("Pro opening")
struct ProOpeningScriptTests {
    @Test func theOpeningLastsTwoPointFourSecondsAndIsTappableFromOnePointFour() {
        #expect(ProOpeningScript.duration == 2.4)
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

    @Test func theCoreRisesIntoThePlanetAndGoesOutAsItArrives() {
        // 1.4–1.5 s it waits at ×1.6 at the focus; at 85% of the rise (2.146 s) it is at the planet, ×2.6; it ends ×4.2 and gone (2.26 s).
        #expect(ProOpeningScript.core.pose(at: 1.45).y == 0 && ProOpeningScript.core.pose(at: 1.45).scale == 1.6)
        #expect(ProOpeningScript.core.pose(at: 1.8).y > 0 && ProOpeningScript.core.pose(at: 1.8).y < 1)
        #expect(ProOpeningScript.core.pose(at: 2.146).y == 1 && ProOpeningScript.core.pose(at: 2.146).scale == 2.6)
        #expect(ProOpeningScript.core.pose(at: 2.26).scale == 4.2 && ProOpeningScript.core.pose(at: 2.26).opacity == 0)
    }

    @Test func theRingExpandsFromFortyPercentToFourteenTimesAndFades() {
        #expect(ProOpeningScript.shockwave.pose(at: 1.25).scale == 0.4)
        #expect(ProOpeningScript.shockwave.pose(at: 2.35).scale == 14)
        #expect(ProOpeningScript.shockwave.pose(at: 2.4).opacity == 0)
    }

    @Test func thePlanetIgnitesPastOneThenSettles() {
        // It ignites as the core reaches it (2.05 s) and rests 0.7 s later, after the opening's light is over.
        #expect(ProOpeningScript.planet.pose(at: 2.05).scale == 0.6)
        #expect(ProOpeningScript.planet.pose(at: 2.54).scale == 1.04)
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

    @Test func theHapticsAreSoftAtTheIgnitionAndSuccessWhenTheButtonLands() {
        #expect(ProOpeningScript.ignitionBeat == 1.25)
        #expect(ProOpeningScript.landing == 2.3)
        #expect(ProOpeningScript.landing < ProOpeningScript.duration)
    }
}
