//
//  AuroraMotionTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

struct AuroraMotionTests {
    private let frame = 1.0 / 30

    @Test func theLightsDriftWithoutJumping() {
        for light in AuroraMotion.Light.allCases {
            var previous = AuroraMotion.center(of: light, at: 0)
            var time = frame
            while time < 60 {
                let current = AuroraMotion.center(of: light, at: time)
                // A fraction of a percent of the card per frame: slow and continuous.
                #expect(hypot(current.x - previous.x, current.y - previous.y) < 0.01)
                previous = current
                time += frame
            }
        }
    }

    @Test func theLightsStayAroundTheCard() {
        for light in AuroraMotion.Light.allCases {
            for step in 0..<1_200 {
                let center = AuroraMotion.center(of: light, at: Double(step) * 0.1)
                #expect((-0.2...1.2).contains(center.x))
                #expect((-0.2...1.2).contains(center.y))
            }
        }
    }

    @Test func eachLightMovesOnItsOwnCycleOfTenToFourteenSeconds() {
        // The first sine of each light repeats within 10-14 s: the distance it covers in one cycle
        // is the card's, not a stall.
        for light in AuroraMotion.Light.allCases {
            let samples = (0..<140).map { AuroraMotion.center(of: light, at: Double($0) * 0.1) }
            let xs = samples.map(\.x), ys = samples.map(\.y)
            #expect((xs.max() ?? 0) - (xs.min() ?? 0) > 0.15)
            #expect((ys.max() ?? 0) - (ys.min() ?? 0) > 0.15)
        }
    }

    @Test func theBorderLightGoesRoundOnceEveryLap() {
        let size = CGSize(width: 340, height: 220)
        let start = AuroraMotion.highlight(at: 2, size: size)
        let lap = AuroraMotion.highlight(at: 2 + AuroraMotion.lapDuration, size: size)
        #expect(abs(start.start - lap.start) < 1e-9)
        #expect(abs(start.span - lap.span) < 1e-9)
        #expect((8.0...10.0).contains(AuroraMotion.lapDuration))
    }

    @Test func theBorderLightMovesForwardAtAnEvenPaceWithoutJumping() {
        let size = CGSize(width: 340, height: 220)
        var previous = AuroraMotion.highlight(at: 0, size: size)
        var time = frame
        while time < AuroraMotion.lapDuration {
            let current = AuroraMotion.highlight(at: time, size: size)
            var step = current.start - previous.start
            if step < -.pi { step += 2 * .pi }
            // Always clockwise, and a few hundredths of a radian a frame.
            #expect(step > 0)
            #expect(step < 0.08)
            #expect(current.span > 0 && current.span < 2 * .pi)
            previous = current
            time += frame
        }
    }

    @Test func theLightCoversAThirdOfTheEdgeAndNeverTheWholeBorder() {
        for size in [CGSize(width: 340, height: 220), CGSize(width: 340, height: 120), CGSize(width: 200, height: 200)] {
            for step in 0..<90 {
                let highlight = AuroraMotion.highlight(at: Double(step) * 0.1, size: size)
                #expect(highlight.span > 0.5)
                #expect(highlight.span < 2 * .pi - 0.5)
            }
        }
    }

    @Test func aPointOnTheEdgeIsFoundByItsFractionClockwise() {
        let size = CGSize(width: 200, height: 100)
        // Top left corner, then the middle of the top edge, the right edge, the bottom and the left.
        #expect(AuroraMotion.offsetFromCenter(atPerimeterFraction: 0, size: size) == CGPoint(x: -100, y: -50))
        #expect(AuroraMotion.offsetFromCenter(atPerimeterFraction: 100.0 / 600, size: size) == CGPoint(x: 0, y: -50))
        #expect(AuroraMotion.offsetFromCenter(atPerimeterFraction: 250.0 / 600, size: size) == CGPoint(x: 100, y: 0))
        #expect(AuroraMotion.offsetFromCenter(atPerimeterFraction: 400.0 / 600, size: size) == CGPoint(x: 0, y: 50))
        #expect(AuroraMotion.offsetFromCenter(atPerimeterFraction: 550.0 / 600, size: size) == CGPoint(x: -100, y: 0))
        // A whole lap is where it began.
        #expect(AuroraMotion.offsetFromCenter(atPerimeterFraction: 1, size: size) == CGPoint(x: -100, y: -50))
    }
}
