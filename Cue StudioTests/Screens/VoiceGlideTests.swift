//
//  VoiceGlideTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("VoiceGlide")
struct VoiceGlideTests {
    private let glide = VoiceGlide()
    private let lineHeight = 40.0

    @Test func aWordOrTwoCatchesUpQuickly() {
        #expect(glide.time(forDistance: 10, lineHeight: lineHeight) == glide.small)
        #expect(glide.time(forDistance: 20, lineHeight: lineHeight) == glide.small)
    }

    @Test func aBigCorrectionGlidesAsSmoothlyAsBefore() {
        #expect(glide.time(forDistance: 80, lineHeight: lineHeight) == PrompterScrollEngine.glideTime)
        #expect(glide.time(forDistance: 400, lineHeight: lineHeight) == PrompterScrollEngine.glideTime)
    }

    @Test func inBetweenGoesInProportion() {
        let time = glide.time(forDistance: 50, lineHeight: lineHeight)
        #expect(time > glide.small && time < glide.large)
        #expect(abs(time - (glide.small + (glide.large - glide.small) * 0.5)) < 0.0001)
    }

    @Test func withoutALayoutItKeepsTheSmoothGlide() {
        #expect(glide.time(forDistance: 10, lineHeight: 0) == glide.large)
    }

    /// The engine eases faster with a shorter glide, and never backward.
    @Test func theEngineUsesTheGlideTime() {
        var quick = PrompterScrollEngine()
        var smooth = PrompterScrollEngine()
        quick.updateLayout(contentHeight: 1000, lineHeight: 40, wordCount: 100)
        smooth.updateLayout(contentHeight: 1000, lineHeight: 40, wordCount: 100)
        quick.glide(toward: 20, by: 0.1, glideTime: 0.2)
        smooth.glide(toward: 20, by: 0.1, glideTime: 0.35)
        #expect(quick.offset > smooth.offset)
        let reached = quick.offset
        quick.glide(toward: 5, by: 0.1, glideTime: 0.2)
        #expect(quick.offset == reached)
    }
}
