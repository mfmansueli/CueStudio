//
//  SendOffScriptTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The send-off (8.2): the numbers of `ANIMACOES` §2 and the board's layout.
@MainActor
@Suite("Send-off")
struct SendOffScriptTests {
    @Test func theStarOfEachNetworkLeavesThreeHundredFiftyMillisecondsAfterTheOneBefore() {
        #expect(SendOffScript.launch(0) == 0.52)
        #expect(abs(SendOffScript.launch(2) - 1.22) < 0.0001)
        #expect(abs(SendOffScript.arrival(0) - 1.57) < 0.0001)
    }

    @Test func theCardRisesWholeThenShrinksAndGoesOutInSixtyFiveHundredths() {
        #expect(SendOffScript.card(at: 0) == SendOffScript.Fold(y: 0, scale: 1, opacity: 1))
        let half = SendOffScript.card(at: 0.325)
        #expect(half.y == -16 && half.scale == 1 && half.opacity == 1)
        let end = SendOffScript.card(at: 0.65)
        #expect(end.y == -30 && abs(end.scale - 0.12) < 0.0001 && end.opacity == 0)
        #expect(SendOffScript.card(at: 3).opacity == 0)
    }

    @Test func aStarIsInTheAirOnlyBetweenItsLaunchAndItsArrivalAndFadesInFast() throws {
        #expect(SendOffScript.star(0, at: 0.4) == nil)
        #expect(SendOffScript.star(0, at: SendOffScript.arrival(0)) == nil)
        let early = try #require(SendOffScript.star(0, at: SendOffScript.launch(0) + 0.03))
        let later = try #require(SendOffScript.star(0, at: SendOffScript.launch(0) + 0.5))
        #expect(early.opacity < 1 && later.opacity == 1)
        #expect(later.progress > early.progress)
        #expect(later.scale < 1 && later.scale > 0.65)
    }

    @Test func theTrailIsNineDotsEachLaterAndFainterThanTheLast() throws {
        #expect(SendOffScript.trailDots == 9)
        let time = SendOffScript.launch(0) + 0.6
        let first = try #require(SendOffScript.star(0, dot: 1, at: time))
        let ninth = try #require(SendOffScript.star(0, dot: 9, at: time))
        let star = try #require(SendOffScript.star(0, at: time))
        #expect(star.progress > first.progress && first.progress > ninth.progress)
        #expect(abs(first.opacity - 0.49) < 0.0001 && abs(ninth.opacity - 0.01) < 0.0001)
        #expect(SendOffScript.star(0, dot: 1, at: SendOffScript.launch(0) + 0.01) == nil, "the dot starts 38 ms after the star")
    }

    @Test func thePlanetPulsesToOneThirtyFiveAndSettlesAtOneTwelve() {
        let arrival = SendOffScript.arrival(0)
        #expect(SendOffScript.planetScale(0, at: arrival - 0.1) == 1)
        let rising = SendOffScript.planetScale(0, at: arrival + 0.1)
        #expect(rising > 1 && rising < 1.5)
        #expect(abs(SendOffScript.planetScale(0, at: arrival + 0.21) - 1.35) < 0.0001, "the peak at 35% of 0.6 s")
        #expect(SendOffScript.planetScale(0, at: arrival + 0.6) == 1.12)
        #expect(SendOffScript.planetScale(0, at: arrival + 3) == 1.12)
    }

    @Test func theRingGoesOutToFiveTimesAndFadesInEightTenths() throws {
        let arrival = SendOffScript.arrival(1)
        #expect(SendOffScript.ring(1, at: arrival - 0.01) == nil && SendOffScript.ring(1, at: arrival + 0.85) == nil)
        let start = try #require(SendOffScript.ring(1, at: arrival))
        #expect(start.scale == 1 && abs(start.opacity - 0.9) < 0.0001)
        let late = try #require(SendOffScript.ring(1, at: arrival + 0.79))
        #expect(late.scale > 4.5 && late.opacity < 0.1)
    }

    @Test func plusOneComesUpOverOnePointFourSecondsThenOverHalfASecond() {
        #expect(SendOffScript.plusDuration(index: 0) == 1.4 && SendOffScript.plusDuration(index: 1) == 0.5)
        #expect(SendOffScript.plus(0, at: SendOffScript.arrival(0) - 0.1).opacity == 0)
        let arrival = SendOffScript.arrival(0)
        #expect(SendOffScript.plus(0, at: arrival + 1.4).opacity == 1 && SendOffScript.plus(0, at: arrival + 1.4).lift == 0)
        #expect(SendOffScript.plus(0, at: arrival + 0.05).lift > 0)
        #expect(SendOffScript.plus(1, at: SendOffScript.arrival(1) + 0.5).opacity == 1)
    }

    @Test func theNumberGrowsByOneWhenItsStarLands() {
        let arrival = SendOffScript.arrival(0)
        #expect(SendOffScript.count(final: 13, index: 0, at: arrival - 0.01) == 12)
        #expect(SendOffScript.count(final: 13, index: 0, at: arrival) == 13)
        #expect(SendOffScript.count(final: 0, index: 0, at: 0) == 0)
    }

    @Test func theNewStarLightsThreeTenthsAfterTheFirstPulseWithAnOvershoot() {
        #expect(SendOffScript.newStarStart == SendOffScript.arrival(0) + 0.3)
        #expect(SendOffScript.newStar(at: SendOffScript.newStarStart - 0.1).opacity == 0)
        let peak = (1...28).map { SendOffScript.newStar(at: SendOffScript.newStarStart + Double($0) * 0.01).scale }.max() ?? 0
        #expect(peak > 1.5, "it grows past ×1.5 on its way to ×1.8 before it settles")
        let end = SendOffScript.newStar(at: SendOffScript.newStarStart + 0.7)
        #expect(end.scale == 1 && end.opacity == 1)
    }

    @Test func threeArrivalsWithinSevenTenthsSoundOneHaptic() {
        #expect(SendOffScript.hapticArrivals(networks: 1).count == 1)
        #expect(SendOffScript.hapticArrivals(networks: 2).count == 2)
        #expect(SendOffScript.hapticArrivals(networks: 3).count == 1)
    }

    @Test func everythingHasLandedBeforeTheEnd() {
        for networks in 1...3 {
            let end = SendOffScript.end(networks: networks)
            #expect(end >= SendOffScript.arrival(networks - 1) + SendOffScript.ringDuration)
            #expect(end >= SendOffScript.newStarStart + SendOffScript.newStarDuration)
        }
    }

    // MARK: - Layout

    @Test func eachNetworkHasItsOwnSpotAndTheBiggestPlanetIsTheOneWithTheMostVideos() {
        let spots = Set(Platform.allCases.map { "\(SendOffLayout.center(of: $0))" })
        #expect(spots.count == Platform.allCases.count)
        let counts: [Platform: Int] = [.tiktok: 13, .reels: 7, .shorts: 6, .youtube: 3, .linkedin: 2, .stories: 1]
        #expect(SendOffLayout.diameter(of: .tiktok, counts: counts) == 20)
        #expect(SendOffLayout.diameter(of: .stories, counts: counts) == 12)
        let swapped: [Platform: Int] = [.tiktok: 1, .reels: 7]
        #expect(SendOffLayout.diameter(of: .reels, counts: swapped) == 20)
        #expect(SendOffLayout.diameter(of: .tiktok, counts: swapped) == 18)
    }

    @Test func theThreePlusOnesNeverShareASpot() {
        let spots = (0..<3).map { index in
            let platform = [Platform.tiktok, .reels, .shorts][index]
            return SendOffLayout.plusSpot(index: index, center: SendOffLayout.center(of: platform), diameter: 18)
        }
        #expect(spots[0].isCentred && !spots[1].isCentred && !spots[2].isCentred)
        #expect(spots[2].point.y > SendOffLayout.center(of: .shorts).y, "the third goes under its planet's name")
        #expect(spots[1].point.y < SendOffLayout.center(of: .reels).y)
    }

    @Test func theArcRunsFromTheCardToThePlanetAndBowsUp() {
        let end = SendOffLayout.center(of: .tiktok)
        let route = SendOffLayout.arc(to: end)
        #expect(SendOffLayout.point(on: route, at: 0) == CGPoint(x: SendOffLayout.card.midX, y: SendOffLayout.card.midY))
        #expect(SendOffLayout.point(on: route, at: 1) == end)
        let middle = SendOffLayout.point(on: route, at: 0.5)
        let chordMiddleY = (route.start.y + end.y) / 2
        #expect(middle.y < chordMiddleY, "the arc bows up")
    }
}
