//
//  VoyageFitTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// 1.3: the galaxies fit between the heading and the chips, a little bigger when there is room and smaller when there is not, and a tap still
/// finds the galaxy under the finger.
@MainActor
struct VoyageFitTests {
    private let height = VoyageFit.cluster.upperBound - VoyageFit.cluster.lowerBound

    @Test func roomToSpareGrowsTheGalaxiesOnlyALittle() {
        let fit = VoyageFit(band: 200...(200 + height * 2))
        #expect(fit.scale == VoyageFit.maxScale)
        #expect(fit.centreY == 200 + height)
    }

    @Test func aTightBandShrinksThemSoTheyNeverRunUnderTheWords() {
        let fit = VoyageFit(band: 300...(300 + height * 0.9))
        #expect(abs(fit.scale - 0.9) < 0.0001)
        let top = fit.centreY - height / 2 * fit.scale
        let bottom = fit.centreY + height / 2 * fit.scale
        #expect(abs(top - 300) < 0.0001 && abs(bottom - (300 + height * 0.9)) < 0.0001)
        #expect(VoyageFit(band: 300...310).scale == VoyageFit.minScale)
    }

    @Test func aTapFindsTheBoardPointUnderIt() {
        let fit = VoyageFit(scale: 1.1, centreY: 450)
        let reels = CGPoint(x: 147, y: 257)
        let middle = (VoyageFit.cluster.lowerBound + VoyageFit.cluster.upperBound) / 2
        let drawn = CGPoint(x: VoyageFit.pivotX + (reels.x - VoyageFit.pivotX) * 1.1, y: 450 + (reels.y - middle) * 1.1)
        let found = fit.boardPoint(drawn)
        #expect(abs(found.x - reels.x) < 0.0001 && abs(found.y - reels.y) < 0.0001)
        #expect(VoyageFit.board.boardPoint(reels) == reels)
    }
}
