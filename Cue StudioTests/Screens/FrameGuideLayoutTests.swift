//
//  FrameGuideLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("FrameGuideLayout")
struct FrameGuideLayoutTests {
    private let phone = CGSize(width: 402, height: 874)

    @Test func portraitFillsTheScreen() {
        #expect(FrameGuideLayout.barHeight(for: .portrait, in: phone) == 0)
    }

    @Test func squareIsMeasuredAgainstTheSensorWidth() {
        let bar = FrameGuideLayout.barHeight(for: .square, in: phone)
        #expect(abs(bar - 191.19) < 0.01)
    }

    @Test func landscapeLeavesAStripInTheMiddle() {
        let bar = FrameGuideLayout.barHeight(for: .landscape, in: phone)
        #expect(abs(bar - 298.73) < 0.01)
    }

    @Test func barsNeverGoNegative() {
        #expect(FrameGuideLayout.barHeight(for: .vertical, in: CGSize(width: 800, height: 400)) == 0)
    }
}
