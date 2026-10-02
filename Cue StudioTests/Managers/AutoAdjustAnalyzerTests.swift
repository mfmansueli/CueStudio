//
//  AutoAdjustAnalyzerTests.swift
//  Cue StudioTests
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Testing
@testable import Cue_Studio

/// Auto's measuring: where it looks, and how Core Image's analysis becomes numbers.
@Suite("Auto adjust analyzer")
struct AutoAdjustAnalyzerTests {
    @Test func framesAreTakenEvenlyAndAwayFromTheEdges() {
        let times = AutoAdjustAnalyzer.sampleTimes(in: [TimeSpan(start: 10, end: 20)], count: 5)
        #expect(times.count == 5)
        #expect(times == times.sorted())
        #expect(times.first! > 10 && times.last! < 20)
        #expect(zip(times, times.dropFirst()).allSatisfy { abs(($1 - $0) - 2) < 0.000_001 })
    }

    @Test func framesFollowTheStretchesTheClipPlays() {
        let spans = [TimeSpan(start: 0, end: 2), TimeSpan(start: 10, end: 18)]
        let times = AutoAdjustAnalyzer.sampleTimes(in: spans, count: 5)
        #expect(times.allSatisfy { time in spans.contains { $0.contains(time) } })
        // By length: the longer stretch gets more of them.
        #expect(times.filter { $0 >= 10 }.count > times.filter { $0 < 2 }.count)
    }

    @Test func nothingToLookAtGivesNoFrames() {
        #expect(AutoAdjustAnalyzer.sampleTimes(in: []).isEmpty)
        #expect(AutoAdjustAnalyzer.sampleTimes(in: [TimeSpan(start: 3, end: 3)]).isEmpty)
    }

    @Test func theNumbersOfTheFiltersCoreImageOffersAreKept() {
        let vibrance = CIFilter.vibrance()
        vibrance.amount = 0.4
        let shadows = CIFilter.highlightShadowAdjust()
        shadows.highlightAmount = 0.8
        shadows.shadowAmount = 0.3
        let curve = CIFilter.toneCurve()
        curve.point1 = CGPoint(x: 0.25, y: 0.3)
        let measured = AutoAdjustAnalyzer.correction(from: [vibrance, shadows, curve])
        #expect(abs(measured.vibrance - 0.4) < 0.001)
        #expect(abs(measured.highlights - 0.8) < 0.001 && abs(measured.shadows - 0.3) < 0.001)
        #expect(measured.tone.count == 5 && abs(measured.tone[1].y - 0.3) < 0.001)
    }

    @Test func anythingElseIsLeftOut() {
        // Not part of an Auto for video: nothing here becomes a correction.
        let measured = AutoAdjustAnalyzer.correction(from: [CIFilter.sepiaTone(), CIFilter.gaussianBlur()])
        #expect(measured.isNeutral)
    }

    @Test func aPlainFrameIsNotGivenFaceOrRedEye() {
        let frame = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let measured = AutoAdjustAnalyzer.correction(from: frame)
        #expect(measured?.face == nil)
    }
}
