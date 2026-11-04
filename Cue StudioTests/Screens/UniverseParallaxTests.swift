//
//  UniverseParallaxTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// Your universe answering the iPhone's tilt (`UniverseParallax`): at rest nothing moves, the nearer a layer the farther it slides, and the disc
/// opens toward the viewer as the iPhone's top tips back, never by more than 18%.
@Suite("Your universe · parallax")
struct UniverseParallaxTests {
    @Test func atRestTheMapIsAsDrawn() {
        let still = UniverseParallax.still
        let point = CGPoint(x: 179, y: 165)
        for depth in [UniverseParallax.Depth.haze, .disc, .core, .planet] {
            #expect(still.moved(point, depth) == point)
        }
        #expect(still.flatten == 1)
    }

    @Test func theNearerTheLayerTheFartherItSlides() {
        let tilted = UniverseParallax(tilt: CGVector(dx: 1, dy: -1))
        let reach = [UniverseParallax.Depth.haze, .disc, .core, .planet].map { tilted.shift($0).dx }
        #expect(reach == reach.sorted() && reach.first ?? 0 > 0, "Haze, disc, YOU, planets: \(reach)")
        #expect(tilted.shift(.planet).dy < 0, "A tilt up moves them up")
    }

    @Test func theDiscOpensAsTheTopTipsBackWithinItsLimit() {
        #expect(abs(UniverseParallax(tilt: CGVector(dx: 0, dy: 1)).flatten - 1.18) < 0.0001)
        #expect(abs(UniverseParallax(tilt: CGVector(dx: 0, dy: -1)).flatten - 0.82) < 0.0001)
    }
}
