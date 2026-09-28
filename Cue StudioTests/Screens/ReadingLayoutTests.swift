//
//  ReadingLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The reading line under the lens, and the text window that follows it.
@Suite("ReadingLayout")
struct ReadingLayoutTests {
    /// iPhone 17: Dynamic Island inset 62, top bar ends at 106, toolbar starts at 628.
    private let iPhone17 = SelfieScreenMetrics()
    /// iPhone SE: status bar inset 20, a shorter screen.
    private let iPhoneSE = SelfieScreenMetrics(screen: CGSize(width: 375, height: 667), topInset: 20, topBarBottom: 64, toolbarTop: 440)
    /// Under the iPhone 17 top bar (106 + 8) and above its toolbar.
    private let windowTopLimit: CGFloat = 114
    private let highestLine: CGFloat = 132
    private let lowestLine: CGFloat = 540
    /// iPhone 16 Pro Max.
    private let proMax = SelfieScreenMetrics(screen: CGSize(width: 440, height: 956), topInset: 62, topBarBottom: 106, toolbarTop: 710)

    private func layout(
        _ metrics: SelfieScreenMetrics? = nil,
        front: Bool = true,
        offset: Double? = nil,
        height: Double = 250,
        width: Double = 0.6
    ) -> ReadingLayout {
        let metrics = metrics ?? iPhone17
        let frame = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: metrics.screen), aspect: .portrait, resolution: .hd1080).frameRect
        return ReadingLayout(metrics: metrics, isFrontCamera: front, frameRect: frame, lineOffset: offset, windowHeight: height, readingWidth: width)
    }

    // MARK: - Line

    @Test func frontCameraLineSitsJustUnderTheLens() {
        let layout = layout()
        #expect(layout.lensY == 31)
        #expect(layout.lineY == 149)
        #expect(layout.lineOffset == 118)
        #expect(layout.isRecommended)
    }

    @Test func rearCameraLineSits36PercentDownTheFrame() {
        let frame = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: iPhone17.screen), aspect: .portrait, resolution: .hd1080).frameRect
        #expect(layout(front: false).lineY == (frame.minY + frame.height * 0.36).rounded())
    }

    @Test func aMovedLineKeepsItsDistanceFromTheLensOnEveryIPhone() {
        for metrics in [iPhone17, iPhoneSE, proMax] {
            let layout = layout(metrics, offset: 150)
            #expect(layout.lineY - layout.lensY == 150)
            #expect(!layout.isRecommended)
        }
    }

    @Test func theLineStaysBetweenTheTopBarAndTheToolbar() {
        #expect(layout(offset: -200).lineY == highestLine)
        #expect(layout(offset: 2000).lineY == lowestLine)
    }

    @Test func storedOffsetsAreClampedToWhatFits() {
        let layout = layout()
        #expect(layout.offset(forLineAt: 10) == Double(highestLine - 31))
        #expect(layout.offset(forLineAt: 200) == 169)
    }

    // MARK: - Window

    @Test func theLineSitsAQuarterDownTheWindowWhenThereIsRoom() {
        let layout = layout(offset: 250)
        #expect(layout.lead == 62.5)
        #expect(layout.windowRect.minY < layout.lineY && layout.lineY < layout.windowRect.maxY)
    }

    @Test func theWindowNeverGoesAboveTheTopBar() {
        // Just under the lens there is no room for a quarter: the window starts under the top bar.
        let layout = layout()
        #expect(layout.windowRect.minY == windowTopLimit)
        #expect(layout.lead >= ReadingLayout.minimumLead)
    }

    @Test func theWindowFollowsTheLine() {
        let upper = layout(offset: 200)
        let lower = layout(offset: 240)
        #expect(lower.windowRect.minY - upper.windowRect.minY == 40)
        #expect(lower.windowRect.height == upper.windowRect.height)
    }

    @Test func theWindowNeverRunsIntoTheToolbar() {
        let layout = layout(offset: 480, height: 380)
        #expect(layout.windowRect.maxY <= 628)
        #expect(layout.windowRect.contains(CGPoint(x: layout.windowRect.midX, y: layout.lineY)))
    }

    @Test func windowSizeStaysInRange() {
        #expect(layout(offset: 250, height: 1000).windowRect.height == 380)
        #expect(layout(offset: 250, height: 20).windowRect.height == 160)
        #expect(layout(width: 0.99).windowRect.width == (402 * 0.93).rounded())
        #expect(layout(width: 0.2).windowRect.width == (402 * 0.5).rounded())
    }

    @Test func theWindowIsCentered() {
        let window = layout().windowRect
        #expect(abs(window.midX - 201) <= 0.5)
    }

    @Test func theLineReachesALittlePastTheWindow() {
        let layout = layout()
        #expect(layout.lineSpan.lowerBound == layout.windowRect.minX - 16)
        #expect(layout.lineSpan.upperBound == 402 - layout.lineSpan.lowerBound)
    }
}
