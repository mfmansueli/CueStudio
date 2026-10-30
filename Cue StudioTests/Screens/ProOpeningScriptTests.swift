//
//  ProOpeningScriptTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The Pro opening (09, "11.4 · Pro paywall — opening moment", with the owner's galaxy of 30/10/2026): 42 streaks, a star that flies up and
/// becomes the galaxy's core, the arms unfurling, the galaxy lying back with its ring, and the content rising.
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

    @Test func theStarFliesUpToTheGalaxyAndBecomesItsCore() {
        // 1.4–1.5 s it waits at ×1.6 at the focus; it reaches the core's place at 2.1 s, smaller, and is gone at 2.18 s.
        #expect(ProOpeningScript.core.pose(at: 1.45).y == 0 && ProOpeningScript.core.pose(at: 1.45).scale == 1.6)
        #expect(ProOpeningScript.core.pose(at: 1.8).y > 0 && ProOpeningScript.core.pose(at: 1.8).y < 1)
        #expect(ProOpeningScript.core.pose(at: 2.1).y == 1 && ProOpeningScript.core.pose(at: 2.1).scale == 0.9)
        #expect(ProOpeningScript.core.pose(at: 2.18).opacity == 0)
        // It bows out to the right on the way and ends on the core.
        let focus = CGPoint(x: 195, y: 375)
        let core = CGPoint(x: 195, y: 148)
        #expect(ProOpeningScript.flight(from: focus, to: core, progress: 0.5).x > 195)
        #expect(ProOpeningScript.flight(from: focus, to: core, progress: 1).y == 148)
    }

    /// The canvas (30/10/2026): the core springs past its size white-hot and cools, the arms unfurl face on from a tenth of their size turned back
    /// 220°, then the galaxy lies back to its slant and the ring wipes in, its nodes popping 45 ms apart.
    @Test func theGalaxyUnfurlsThenLiesBackAndItsRingComesIn() {
        #expect(ProOpeningScript.coreBirth.pose(at: 1.98).scale == 0)
        #expect(ProOpeningScript.coreBirth.pose(at: 2.295).scale == 1.5)
        #expect(ProOpeningScript.coreBirth.pose(at: ProOpeningScript.settled).scale == 1)
        #expect(ProOpeningScript.whiteHot.pose(at: 2.0).opacity == 1 && ProOpeningScript.whiteHot.pose(at: 3.1).opacity == 0)
        #expect(ProOpeningScript.unfurl.pose(at: 1.98).scale == 0.1 && ProOpeningScript.unfurl.pose(at: 1.98).rotation == -220)
        #expect(ProOpeningScript.unfurl.pose(at: 2.83).scale == 1 && ProOpeningScript.unfurl.pose(at: 2.83).rotation == 0)
        #expect(ProOpeningScript.tilt.pose(at: 2.25).scale == 0)
        #expect(ProOpeningScript.tilt.pose(at: 2.75).scale > 1, "it lies back past its slant on the spring")
        #expect(ProOpeningScript.tilt.pose(at: 3.05).scale == 1)
        #expect(ProOpeningScript.ringWipe.pose(at: 2.4).scale == 0 && ProOpeningScript.ringWipe.pose(at: 3.1).scale == 1)
        #expect(ProOpeningScript.nodePop(0, of: 12).pose(at: 2.5).opacity == 0)
        #expect(ProOpeningScript.nodePop(11, of: 12).pose(at: ProOpeningScript.settled).scale == 1)
        #expect(ProOpeningScript.nodeGap(12) == 0.045 && ProOpeningScript.nodeGap(30) == 0.018)
    }

    @Test func nothingOfTheGalaxyShowsBeforeTheStarArrives() {
        for second in stride(from: 0.0, to: 1.98, by: 0.05) {
            #expect(ProOpeningScript.unfurlFade.pose(at: second).opacity == 0, "the arms at \(second) s")
            #expect(ProOpeningScript.coreBirth.pose(at: second).scale == 0, "the core at \(second) s")
            #expect(ProOpeningScript.ringWipe.pose(at: second).scale == 0, "the ring at \(second) s")
            #expect(ProOpeningScript.arrival.pose(at: second).opacity == 0, "the bloom at \(second) s")
        }
    }

    @Test func theRingExpandsFromFortyPercentToFourteenTimesAndFades() {
        #expect(ProOpeningScript.shockwave.pose(at: 1.25).scale == 0.4)
        #expect(ProOpeningScript.shockwave.pose(at: 2.35).scale == 14)
        #expect(ProOpeningScript.shockwave.pose(at: 2.4).opacity == 0)
    }

    @Test func theContentRisesInItsTurnAndIsInPlaceAtTheEnd() {
        let title = ProOpeningScript.reveal(.title)
        #expect(title.pose(at: 2.3).opacity == 0 && title.pose(at: 2.3).y == 18)
        #expect(abs(ProOpeningScript.reveal(.list, line: 1).keyframes[0].time - ProOpeningScript.reveal(.list).keyframes[0].time - 0.06) < 0.0001)
        let blocks: [ProOpeningScript.Block] = [.title, .subtitle, .exports, .ultra, .list, .plans, .button, .finePrint, .links]
        for block in blocks {
            let pose = ProOpeningScript.reveal(block, line: block == .list ? 3 : 0).pose(at: ProOpeningScript.settled)
            #expect(pose.opacity == 1 && pose.y == 0 && pose.blur == 0, "\(block)")
        }
        #expect(ProOpeningScript.badge.pose(at: ProOpeningScript.settled).scale == 1)
        #expect(ProOpeningScript.settled > ProOpeningScript.duration)
    }

    @Test func theHapticsFollowTheIgnitionTheUnfurlAndTheRing() {
        #expect(ProOpeningScript.ignitionBeat == 1.25)
        #expect(ProOpeningScript.unfurlBeat < ProOpeningScript.settleBeat)
        #expect(ProOpeningScript.ringBeat + 11 * ProOpeningScript.nodeGap(12) < ProOpeningScript.settled)
    }
}
