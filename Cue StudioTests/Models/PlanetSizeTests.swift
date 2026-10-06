//
//  PlanetSizeTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The planets of 9.2 grow with `d = 14 + 24 · ln(min(n, 365)) / ln(365)`.
@Suite("PlanetSize")
struct PlanetSizeTests {
    @Test func theBoardsTable() {
        #expect(PlanetSize.diameter(videos: 1) == 14)
        #expect(PlanetSize.diameter(videos: 12) == 24)
        #expect(PlanetSize.diameter(videos: 52) == 30)
        #expect(PlanetSize.diameter(videos: 156) == 35)
        #expect(PlanetSize.diameter(videos: 365) == 38)
    }

    @Test func aPlanetNeverPassesTheCore() {
        #expect(PlanetSize.diameter(videos: 5_000) == PlanetSize.maximum)
        #expect(PlanetSize.diameter(videos: 0) == 0, "no videos, no planet")
    }

    @Test func itNeverShrinks() {
        let sizes = (1...400).map { PlanetSize.diameter(videos: $0) }
        #expect(sizes == sizes.sorted())
    }

    @Test func detailsComeAtFiftyTwoOneFiftySixAndThreeSixtyFive() {
        #expect(PlanetSize.detail(videos: 51) == .sphere)
        #expect(PlanetSize.detail(videos: 52) == .glow)
        #expect(PlanetSize.detail(videos: 156) == .ring)
        #expect(PlanetSize.detail(videos: 365) == .moon)
    }

    @Test func theNextDetailAndHowFarItIs() {
        #expect(PlanetSize.next(videos: 12)?.detail == .glow)
        #expect(PlanetSize.next(videos: 12)?.remaining == 40)
        #expect(PlanetSize.next(videos: 60)?.detail == .ring)
        #expect(PlanetSize.next(videos: 200)?.remaining == 165)
        #expect(PlanetSize.next(videos: 365) == nil)
    }
}
