//
//  SelfiePanelFrameTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("SelfiePanelFrame")
struct SelfiePanelFrameTests {
    private let reference = CGSize(width: 402, height: 874)

    @Test func tikTokPanelSitsWhereTheDesignPutsIt() {
        let layout = TestData.preset(.tiktok).prompter
        let frame = SelfiePanelFrame.frame(layout: layout, readingWidth: layout.width, screen: reference, reference: reference)
        #expect(frame.minY == 118)
        #expect(frame.height == 280)
        #expect(frame.width == 233)
        #expect(frame.minX == 85)
    }

    @Test func readingWidthStaysBetweenHalfAndThreeQuarters() {
        let layout = TestData.preset(.reels).prompter
        let narrow = SelfiePanelFrame.frame(layout: layout, readingWidth: 0.2, screen: reference, reference: reference)
        let wide = SelfiePanelFrame.frame(layout: layout, readingWidth: 0.95, screen: reference, reference: reference)
        #expect(narrow.width == 201)
        #expect(wide.width == 302)
    }

    @Test func positionScalesWithTheScreenHeight() {
        let layout = TestData.preset(.linkedin).prompter
        let frame = SelfiePanelFrame.frame(layout: layout, readingWidth: 0.64, screen: CGSize(width: 402, height: 437), reference: reference)
        #expect(frame.minY == 98)
        #expect(frame.height == 120)
    }

    @Test func youTubePanelFitsInTheBarAboveTheVideo() {
        let layout = TestData.preset(.youtube).prompter
        let bar = FrameGuideLayout.barHeight(for: .landscape, in: reference)
        let frame = SelfiePanelFrame.frame(layout: layout, readingWidth: layout.width, screen: reference, reference: reference, bottomLimit: bar)
        #expect(frame.minY == 104)
        #expect(frame.maxY <= bar - SelfiePanelFrame.barGap)
    }
}
