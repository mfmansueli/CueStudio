//
//  CaptureFormatSelectorTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("CaptureFormatSelector")
struct CaptureFormatSelectorTests {
    private let formats = [
        CaptureFormatCandidate(width: 1280, height: 720, maxFrameRate: 60, isStandardPixelFormat: true),
        CaptureFormatCandidate(width: 1920, height: 1080, maxFrameRate: 30, isStandardPixelFormat: true),
        CaptureFormatCandidate(width: 1920, height: 1080, maxFrameRate: 60, isStandardPixelFormat: true),
        CaptureFormatCandidate(width: 1920, height: 1080, maxFrameRate: 60, isStandardPixelFormat: false),
        CaptureFormatCandidate(width: 3840, height: 2160, maxFrameRate: 30, isStandardPixelFormat: true),
    ]

    @Test func picksTheLeastDemandingExactFormat() {
        #expect(CaptureFormatSelector.bestIndex(in: formats, resolution: .hd1080, frameRate: .fps30) == 1)
    }

    @Test func prefersStandardOverHDR() {
        #expect(CaptureFormatSelector.bestIndex(in: formats, resolution: .hd1080, frameRate: .fps60) == 2)
    }

    @Test func fallsBackToTheLargestSmallerFormatAtTheFrameRate() {
        #expect(CaptureFormatSelector.bestIndex(in: formats, resolution: .uhd4K, frameRate: .fps60) == 2)
    }

    @Test func nothingWhenNoFormatReachesTheFrameRate() {
        let slow = [CaptureFormatCandidate(width: 1920, height: 1080, maxFrameRate: 30, isStandardPixelFormat: true)]
        #expect(CaptureFormatSelector.bestIndex(in: slow, resolution: .hd1080, frameRate: .fps60) == nil)
    }
}
