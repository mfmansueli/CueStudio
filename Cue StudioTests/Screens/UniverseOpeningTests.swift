//
//  UniverseOpeningTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Your universe builds itself as it opens: YOU first, then the orbits, the videos flying out one after the other, the planets born at the end
/// of their lights, the newest star last; everything in place by the end.
struct UniverseOpeningTests {
    @Test func youIsBornWhiteHotAndCoolsToItsColour() {
        #expect(UniverseOpening.core.pose(at: 0).opacity == 0)
        #expect(UniverseOpening.coreWhite.pose(at: 0.1).opacity == 1)
        #expect(UniverseOpening.coreWhite.pose(at: 0.9).opacity == 0)
        #expect(UniverseOpening.core.pose(at: UniverseOpening.duration).scale == 1)
    }

    @Test func theOrbitsDrawTheInnerOneFirst() {
        #expect(UniverseOpening.innerOrbit.pose(at: 0.6).scale > UniverseOpening.outerOrbit.pose(at: 0.6).scale)
        #expect(UniverseOpening.innerOrbit.pose(at: UniverseOpening.duration).scale == 1)
        #expect(UniverseOpening.outerOrbit.pose(at: UniverseOpening.duration).scale == 1)
    }

    @Test func theVideosLeaveOneAfterTheOtherAndAllLand() {
        let count = 23
        #expect(UniverseOpening.dotFlight(index: 0, count: count, at: 0.45) == 0)
        #expect(UniverseOpening.dotFlight(index: 0, count: count, at: 0.8) > UniverseOpening.dotFlight(index: 10, count: count, at: 0.8))
        for index in 0..<count {
            #expect(UniverseOpening.dotFlight(index: index, count: count, at: UniverseOpening.duration) == 1)
            #expect(UniverseOpening.dotLanding(index: index, count: count, at: UniverseOpening.duration + 1) == nil)
        }
    }

    @Test func aPlanetIsBornWhenItsLightArrives() {
        for index in 0..<6 {
            let born = UniverseOpening.planetBirth(index)
            #expect(UniverseOpening.planet(index: index, at: born - 0.05).scale == 0)
            #expect(UniverseOpening.routeLight(index: index, at: born) == 1)
            #expect(UniverseOpening.planet(index: index, at: born).white == 1)
            #expect(born + 0.6 <= UniverseOpening.duration, "planet \(index) settles inside the opening")
            let rest = UniverseOpening.planet(index: index, at: UniverseOpening.duration)
            #expect(rest.scale == 1 && rest.white == 0)
            #expect(UniverseOpening.planetSparks(index: index, at: born - 0.05).opacity == 0)
        }
    }

    @Test func theNewestStarIgnitesLast() {
        #expect(UniverseOpening.newest.pose(at: 2.25).opacity == 0)
        #expect(UniverseOpening.newest.pose(at: UniverseOpening.duration).scale == 1)
        let beats = UniverseOpening.beats(planets: 3)
        #expect(beats.count == 4 && beats.first?.isPlanet == false)
    }
}
