//
//  CropMathTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("CropMath")
struct CropMathTests {
    private let portrait = CGSize(width: 1080, height: 1920)

    @Test func portraitVideoStaysWhole() {
        #expect(CropMath.centeredCrop(in: portrait, aspect: 9.0 / 16.0) == CGRect(x: 0, y: 0, width: 1080, height: 1920))
    }

    @Test func squareCropsTopAndBottom() {
        #expect(CropMath.centeredCrop(in: portrait, aspect: 1) == CGRect(x: 0, y: 420, width: 1080, height: 1080))
    }

    @Test func landscapeFromPortraitHasEvenDimensions() {
        #expect(CropMath.centeredCrop(in: portrait, aspect: 16.0 / 9.0) == CGRect(x: 0, y: 657, width: 1080, height: 606))
    }

    @Test func portraitFromLandscapeCropsTheSides() {
        #expect(CropMath.centeredCrop(in: CGSize(width: 1920, height: 1080), aspect: 9.0 / 16.0) == CGRect(x: 657, y: 0, width: 606, height: 1080))
    }

    @Test func emptySizeGivesAnEmptyCrop() {
        #expect(CropMath.centeredCrop(in: .zero, aspect: 1) == .zero)
    }
}
