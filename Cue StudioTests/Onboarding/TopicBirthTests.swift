//
//  TopicBirthTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
@testable import Cue_Studio

/// 1.2: a picked topic's light leaves its chip, lands on its orbit 1.75 s later, the planet springs out there and the orbit draws round it.
/// Every moment is the board's own (`TopicBirth.pose` reads the layers of `1.2_topics` at `age + 2.6`).
@MainActor
@Suite("Topic birth")
struct TopicBirthTests {
    private let birth = TopicBirth(
        color: .pink, tap: Date(timeIntervalSince1970: 0),
        from: CGPoint(x: 85, y: 596), to: CGPoint(x: 78, y: 422), core: CGPoint(x: 195, y: 360)
    )

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }

    // MARK: - The route

    @Test func theLightGoesFromTheChipToTheOrbit() {
        #expect(birth.point(at: 0) == birth.from)
        #expect(birth.point(at: 1) == birth.to)
        #expect(birth.point(at: -3) == birth.from && birth.point(at: 9) == birth.to)
    }

    @Test func theRouteBowsAwayFromTheCoreAndNeverCrossesIt() {
        let chordMiddle = CGPoint(x: (birth.from.x + birth.to.x) / 2, y: (birth.from.y + birth.to.y) / 2)
        #expect(distance(birth.point(at: 0.5), birth.core) > distance(chordMiddle, birth.core))
        let nearest = stride(from: 0.0, through: 1.0, by: 0.02).map { distance(birth.point(at: $0), birth.core) }.min() ?? 0
        #expect(nearest > 40, "the light goes round the core, not through it")
    }

    @Test func theRouteBowsTheSameSideWhicheverWayTheTopicLies() {
        let right = TopicBirth(color: .pink, tap: .now, from: CGPoint(x: 300, y: 596), to: CGPoint(x: 330, y: 422), core: CGPoint(x: 195, y: 360))
        let chordMiddle = CGPoint(x: (right.from.x + right.to.x) / 2, y: (right.from.y + right.to.y) / 2)
        #expect(distance(right.point(at: 0.5), right.core) > distance(chordMiddle, right.core))
    }

    // MARK: - The board's layers

    @Test func everyLayerTheBirthReadsIsInTheBoard() {
        let single = [
            TopicBirth.chipRing, TopicBirth.chipCross, TopicBirth.routeLine, TopicBirth.routeTail, TopicBirth.head, TopicBirth.landingCross,
            TopicBirth.planet, TopicBirth.orbit, TopicBirth.orbitLight, TopicBirth.label,
        ]
        let layers = single
            + TopicBirth.chipSparks + TopicBirth.followers + TopicBirth.landingSparks + TopicBirth.streaks + TopicBirth.rings
            + TopicBirth.glints.map(\.layer)
        for layer in layers { #expect(TopicBirth.clip.has(layer), "\(layer) is not in 1.2_topics") }
    }

    @Test func theBoardHasEightSparksOnTheChipAndNineOnTheLanding() {
        #expect(TopicBirth.chipSparks.count == 8)
        #expect(TopicBirth.landingSparks.count == 9)
        #expect(TopicBirth.streaks.count == 10)
        #expect(TopicBirth.followers.count == 8)
        #expect(TopicBirth.glints.count == 5)
        #expect(TopicBirth.rings.count == 3)
    }

    @Test func theChipLightsAtTheTap() {
        #expect(TopicBirth.pose(TopicBirth.chipRing, at: 0).opacity < 0.1)
        #expect(TopicBirth.pose(TopicBirth.chipRing, at: 0.05).opacity > 0.8)
        #expect(TopicBirth.pose(TopicBirth.chipRing, at: 0.7).opacity == 0)
        #expect(TopicBirth.pose(TopicBirth.chipSparks[0], at: 0.2).opacity > 0.5)
    }

    @Test func theLightTravelsFromJustAfterTheTapToTheLanding() {
        #expect(TopicBirth.pose(TopicBirth.head, at: 0.05).opacity == 0)
        #expect(TopicBirth.pose(TopicBirth.head, at: 0.2).opacity == 1)
        let started = TopicBirth.pose(TopicBirth.head, at: 0.2).along ?? 1
        let middle = TopicBirth.pose(TopicBirth.head, at: 1.0).along ?? 0
        let landed = TopicBirth.pose(TopicBirth.head, at: TopicBirth.landing).along ?? 0
        #expect(started < middle && middle < landed)
        #expect(abs(landed - 1) < 0.01)
        #expect(TopicBirth.pose(TopicBirth.routeLine, at: 0.05).drawn == 0)
        #expect(abs(TopicBirth.pose(TopicBirth.routeLine, at: TopicBirth.landing).drawn - 1) < 0.01)
    }

    @Test func thePlanetSpringsOutAtTheLandingAndSettlesAtItsSize() {
        #expect(TopicBirth.pose(TopicBirth.planet, at: 1.0).opacity == 0)
        #expect(TopicBirth.pose(TopicBirth.planet, at: 1.95).scale > 2, "×2.4 at the first beat")
        #expect(TopicBirth.pose(TopicBirth.planet, at: 2.15).scale < 1, "the spring goes under 1 (×0.82)…")
        #expect(TopicBirth.pose(TopicBirth.planet, at: 2.33).scale > 1, "…and over it (×1.1)…")
        #expect(TopicBirth.pose(TopicBirth.planet, at: 2.6).scale == 1, "…before it rests")
        #expect(TopicBirth.pose(TopicBirth.planet, at: TopicBirth.duration).scale == 1)
    }

    @Test func theOrbitDrawsAfterTheLandingAndTheNameArrivesLast() {
        #expect(TopicBirth.pose(TopicBirth.orbit, at: 1.0).drawn == 0)
        #expect(TopicBirth.pose(TopicBirth.orbit, at: 2.4).drawn > 0.3 && TopicBirth.pose(TopicBirth.orbit, at: 2.4).drawn < 0.9)
        #expect(abs(TopicBirth.pose(TopicBirth.orbit, at: 3.1).drawn - 1) < 0.01)
        #expect(TopicBirth.pose(TopicBirth.label, at: 1.9).opacity == 0)
        #expect(TopicBirth.pose(TopicBirth.label, at: 2.7).opacity == 1)
    }

    @Test func aWorldOnceBornStaysWhileTheBoardLoopsAway() {
        // The board fades its demo out and starts over near ten seconds; the app's age stops at six.
        #expect(TopicBirth.pose(TopicBirth.planet, at: 60).opacity == 1)
        #expect(TopicBirth.pose(TopicBirth.orbit, at: 60).drawn > 0.99)
    }

    @Test func nothingOfTheLightShowIsLeftWhenTheBirthEnds() {
        let single = [TopicBirth.chipRing, TopicBirth.chipCross, TopicBirth.routeLine, TopicBirth.routeTail, TopicBirth.head, TopicBirth.landingCross]
        let overlay = single
            + TopicBirth.chipSparks + TopicBirth.followers + TopicBirth.landingSparks + TopicBirth.streaks + TopicBirth.rings
            + TopicBirth.glints.map(\.layer)
        for layer in overlay {
            #expect(TopicBirth.pose(layer, at: TopicBirth.duration).opacity == 0, "\(layer) is still lit at \(TopicBirth.duration) s")
        }
    }

    // MARK: - What the app adds

    @Test func theChipBarPopsInWithAnOvershoot() {
        #expect(TopicBirth.bar.pose(at: 0).scale == 0)
        #expect(TopicBirth.bar.pose(at: 0.30).scale == 1)
        let overshoot = (1...24).map { TopicBirth.bar.pose(at: 0.05 + Double($0) * 0.01).scale }.max() ?? 0
        #expect(overshoot > 1, "the spring goes past 1 before it settles")
    }

    @Test func theLightAcrossTheChipAndTheRingOfTheButtonPlayOnce() {
        #expect(TopicBirth.sweep.pose(at: 0).opacity == 0 && TopicBirth.sweep.pose(at: 0.3).opacity == 1 && TopicBirth.sweep.pose(at: 1).opacity == 0)
        #expect(TopicBirth.button.pose(at: 1.0).opacity == 0)
        #expect(TopicBirth.button.pose(at: 3.2).opacity == 0)
        #expect(TopicBirth.duration >= 3.4, "the last of it (the rings at the landing) ends at 3.25 s")
    }
}
