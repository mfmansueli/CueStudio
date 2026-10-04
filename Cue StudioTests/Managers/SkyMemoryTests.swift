//
//  SkyMemoryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("SkyMemory")
struct SkyMemoryTests {
    @Test func eachIdeaSentAddsAStar() {
        let isolated = TestDefaults()
        defer { isolated.tearDown() }
        let sky = SkyMemory(defaults: isolated.defaults)
        #expect(sky.points.isEmpty)
        sky.addStar()
        sky.addStar()
        #expect(sky.points.count == 2)
    }

    @Test func fourteenAreDrawnAndFiftyAreKept() {
        let isolated = TestDefaults()
        defer { isolated.tearDown() }
        let sky = SkyMemory(defaults: isolated.defaults)
        for _ in 0..<60 { sky.addStar() }
        #expect(sky.points.count == 50)
        #expect(sky.visible.count == 14)
        #expect(sky.visible == Array(sky.points.suffix(14)))
    }

    @Test func starsSurviveARelaunch() {
        let isolated = TestDefaults()
        defer { isolated.tearDown() }
        let first = SkyMemory(defaults: isolated.defaults)
        for _ in 0..<5 { first.addStar() }
        #expect(SkyMemory(defaults: isolated.defaults).points == first.points)
    }

    @Test func aNewStarNeverLandsWhereAnEarlierOneIsAfterOldOnesAreDropped() {
        let isolated = TestDefaults()
        defer { isolated.tearDown() }
        let sky = SkyMemory(defaults: isolated.defaults)
        for _ in 0..<50 { sky.addStar() }
        let next = sky.addStar()
        #expect(!sky.points.dropLast().contains(next))
    }

    @Test func everyPlaceIsInsideTheSkyAndNoTwoAreOnTopOfEachOther() {
        let places = (0..<50).map { SkyMemory.point(at: $0) }
        for place in places {
            #expect((0.0...1.0).contains(place.x) && (0.0...1.0).contains(place.y))
        }
        for (i, a) in places.enumerated() {
            for b in places.dropFirst(i + 1) {
                #expect(hypot(a.x - b.x, a.y - b.y) > 0.01)
            }
        }
    }
}

@MainActor
@Suite("SkyMemory · the star's flight")
struct SkyMemoryFlightTests {
    @Test func theStarArrivesAndStaysAsOneOfYourStars() async {
        let isolated = TestDefaults()
        defer { isolated.tearDown() }
        let sky = SkyMemory(defaults: isolated.defaults)
        await sky.launchStar(from: CGPoint(x: 300, y: 400), reduceMotion: true)
        #expect(sky.points.count == 1)
        #expect(sky.flight == nil)
        #expect(sky.points.first == SkyMemory.point(at: 0))
    }

    @Test func theFlightLastsAboutAsLongAsThePrototypesWithMotionAndLessWithout() {
        #expect(SkyMemory.travel + SkyMemory.glint == .milliseconds(1140))
        #expect(SkyMemory.reducedBeat < SkyMemory.travel)
    }
}
