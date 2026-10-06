//
//  StarfieldAstronautTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The astronaut of the Adrift sky: small, slow, always inside the screen, bouncing off its edges like a ball in zero gravity.
@Suite("StarfieldMath · Astronaut")
struct StarfieldAstronautTests {
    private let screens = [CGSize(width: 402, height: 874), CGSize(width: 375, height: 667), CGSize(width: 820, height: 1180)]
    private var half: Double { Double(StarfieldMath.astronautSize) / 2 + 1 }

    // MARK: - Where he is

    @Test func heIsTheSameEveryTimeItIsAsked() {
        for time in [0.0, 5, 123.4, 4000] {
            #expect(StarfieldMath.astronaut(at: time, size: screens[0], seed: 27) == StarfieldMath.astronaut(at: time, size: screens[0], seed: 27))
        }
        #expect(StarfieldMath.astronaut(at: 60, size: screens[0], seed: 27) != StarfieldMath.astronaut(at: 60, size: screens[0], seed: 28))
    }

    @Test func heNeverLeavesTheScreen() {
        for screen in screens {
            var worst = 0.0
            for step in 0..<14_400 {
                let spot = StarfieldMath.astronaut(at: Double(step) * 0.5, size: screen, seed: 27).position
                // How far outside the walls he is, if at all.
                worst = max(worst, half - spot.x, spot.x - (screen.width - half), half - spot.y, spot.y - (screen.height - half))
            }
            #expect(worst < 0.001, "\(worst) pt outside the screen on \(screen)")
        }
    }

    @Test func heReachesEveryEdgeOfTheScreenInTheCourseOfAnHour() {
        for screen in screens {
            var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
            for step in 0..<7_200 {
                let spot = StarfieldMath.astronaut(at: Double(step) * 0.5, size: screen, seed: 27).position
                minX = min(minX, spot.x); maxX = max(maxX, spot.x); minY = min(minY, spot.y); maxY = max(maxY, spot.y)
            }
            #expect(minX < half + 2 && maxX > screen.width - half - 2, "across, on \(screen)")
            #expect(minY < half + 2 && maxY > screen.height - half - 2, "down, on \(screen)")
        }
    }

    @Test func heNeverJumpsAndNeverSpeedsUp() {
        // At most 10 pt a second along each axis, plus the float (4 pt, 9 and 13 s): well under 16 pt a second, so 2 pt in a tenth of a second.
        for screen in screens {
            var previous = StarfieldMath.astronaut(at: 0, size: screen, seed: 27)
            var farthest = 0.0
            for step in 1..<18_000 {
                let next = StarfieldMath.astronaut(at: Double(step) * 0.1, size: screen, seed: 27)
                farthest = max(farthest, hypot(next.position.x - previous.position.x, next.position.y - previous.position.y))
                previous = next
            }
            #expect(farthest <= 2, "moved \(farthest) pt in 0.1 s on \(screen)")
        }
    }

    // MARK: - How he is turned

    @Test func heTurnsSmoothlyEvenAtABounce() {
        var previous = StarfieldMath.astronaut(at: 0, size: screens[0], seed: 27)
        var sharpest = 0.0
        for step in 1..<18_000 {
            let next = StarfieldMath.astronaut(at: Double(step) * 0.1, size: screens[0], seed: 27)
            sharpest = max(sharpest, abs(next.angle - previous.angle))
            previous = next
        }
        #expect(sharpest <= 0.15, "turned \(sharpest) rad in 0.1 s")
    }

    // MARK: - Size and fade

    @Test func heIsSmallAndEasesInInsteadOfAppearing() {
        #expect(StarfieldMath.astronautSize <= 40)
        #expect(StarfieldMath.astronaut(at: 0, size: screens[0], seed: 27).opacity == 0)
        #expect(abs(StarfieldMath.astronaut(at: StarfieldMath.astronautFadeIn / 2, size: screens[0], seed: 27).opacity - 0.5) < 0.0001)
        #expect(StarfieldMath.astronaut(at: StarfieldMath.astronautFadeIn, size: screens[0], seed: 27).opacity == 1)
        #expect(StarfieldMath.astronaut(at: 1000, size: screens[0], seed: 27).opacity == 1)
        #expect(StarfieldMath.astronaut(at: 60, size: screens[0], seed: 27).size == StarfieldMath.astronautSize)
    }

    @Test func aTinyScreenDoesNotBreakHim() {
        let astronaut = StarfieldMath.astronaut(at: 500, size: CGSize(width: 10, height: 10), seed: 27)
        #expect(astronaut.position.x.isFinite && astronaut.position.y.isFinite && astronaut.angle.isFinite)
    }

    // MARK: - The bounce

    @Test func aPositionInsideTheWallsIsLeftAlone() {
        let hit = StarfieldMath.bounce(40, in: 10...110, speed: 8)
        #expect(hit.value == 40 && hit.count == 0)
        #expect(abs(hit.secondsSince - 30 / 8) < 0.0001)
    }

    @Test func pastTheFarWallHeComesBackAndPastTheNearOneHeGoesOnAgain() {
        let far = StarfieldMath.bounce(130, in: 10...110, speed: 10)
        #expect(abs(far.value - 90) < 0.0001 && far.count == 1)
        // Out at the far wall, back to the near one (raw 210) and off it again: 20 pt in.
        let back = StarfieldMath.bounce(230, in: 10...110, speed: 10)
        #expect(abs(back.value - 30) < 0.0001 && back.count == 2)
        let near = StarfieldMath.bounce(-5, in: 10...110, speed: 10)
        #expect(abs(near.value - 25) < 0.0001 && near.count == -1)
        // A bounce keeps its speed: the time since the wall is the distance from it over the speed.
        #expect(abs(far.secondsSince - 2) < 0.0001)
    }

    @Test func theBounceNeverLeavesTheWalls() {
        var worst = 0.0
        for raw in stride(from: -500.0, through: 800, by: 1.7) {
            let hit = StarfieldMath.bounce(raw, in: 20...320, speed: 9)
            worst = max(worst, 20 - hit.value, hit.value - 320)
        }
        #expect(worst < 0.000001, "\(worst) outside the walls")
    }
}
