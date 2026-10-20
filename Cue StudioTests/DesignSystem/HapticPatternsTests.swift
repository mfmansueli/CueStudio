//
//  HapticPatternsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The haptics drawn in time with the screen: each one has to land inside what it follows, and stay a gesture (never a long buzz).
@MainActor
struct HapticPatternsTests {
    @Test func theSparklesTicksFadeAndEndBeforeTheLastSparkleLights() {
        let beats = HapticPatterns.sparkles
        #expect(beats.allSatisfy { $0.duration == nil }, "Ticks, not a hum")
        #expect(zip(beats, beats.dropFirst()).allSatisfy { $0.time < $1.time && $0.intensity > $1.intensity }, "Each tick later and lighter")
        #expect((beats.last?.time ?? 1) < InspirationStarBurst.duration)
    }

    @Test func theTakeoffSwellsWhileTheStarRisesAndEndsWithIt() {
        let beats = HapticPatterns.takeoff
        let hum = beats.first { $0.duration != nil }
        #expect(hum != nil)
        #expect((hum?.endIntensity ?? 0) > (hum?.intensity ?? 1), "The hum swells")
        let end = beats.map { $0.time + ($0.duration ?? 0) }.max() ?? 0
        #expect(abs(end - IdeaTransitionService.riseDuration) < 0.1, "It ends as the star stops and ignites")
    }

    @Test func everyPatternIsShortAndInRange() {
        for beats in [HapticPatterns.sparkles, HapticPatterns.takeoff, HapticPatterns.landing, HapticPatterns.commit, HapticPatterns.finish] {
            #expect(beats.first?.time == 0, "Starts with the touch")
            #expect(beats.map { $0.time + ($0.duration ?? 0) }.max() ?? 0 <= IdeaTransitionService.riseDuration)
            #expect(beats.allSatisfy { (0...1).contains($0.intensity) && (0...1).contains($0.sharpness) })
        }
    }
}
