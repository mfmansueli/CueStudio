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
        #expect(abs((beats.last?.time ?? 0) - IdeaTransitionService.ignitionTime) < 0.02, "Its last tap is the ignition")
        #expect(abs((hum?.time ?? 0) - IdeaTransitionService.launchDelay) < 0.02, "The hum starts as the star leaves the arrow")
    }

    @Test func everyPatternIsShortAndInRange() {
        let patterns = [
            HapticPatterns.sparkles, HapticPatterns.takeoff, HapticPatterns.landing, HapticPatterns.commit, HapticPatterns.finish,
            HapticPatterns.listen, HapticPatterns.ultraOn, HapticPatterns.ultraIgnite, HapticPatterns.appleOn,
            HapticPatterns.platformOn, HapticPatterns.ultraSendCharged,
        ]
        for beats in patterns {
            #expect(beats.first?.time == 0, "Starts with the touch")
            #expect(beats.map { $0.time + ($0.duration ?? 0) }.max() ?? 0 <= IdeaTransitionService.riseDuration)
            #expect(beats.allSatisfy { (0...1).contains($0.intensity) && (0...1).contains($0.sharpness) })
        }
    }

    /// Ultra AI's: the tap that lights the writer chip falls when the ✦ lands on it.
    @Test func ultraLightsTheChipAsTheStarLands() {
        #expect(HapticPatterns.ultraOn.contains { $0.duration == nil && abs($0.time - UltraMotion.hop) < 0.01 && $0.intensity > 0.5 })
    }

    @Test func appleIntelligenceSwellsWhileItsLightGoesRound() {
        let hum = HapticPatterns.appleOn.first { $0.duration != nil }
        #expect(HapticPatterns.appleOn.first?.duration == nil, "A tap as the symbol bounces")
        #expect((hum?.endIntensity ?? 0) > (hum?.intensity ?? 1), "The hum swells")
        #expect(HapticPatterns.appleOn.map { $0.time + ($0.duration ?? 0) }.max() ?? 0 <= DockChipLight.duration, "It ends with the light")
    }

    /// The filter row unfolding: a tick for each chip as it comes free, the nearest first and lighter after; picking: a tap on the touch
    /// and a firmer one as the last chip lands.
    @Test func theFilterRowTicksAsEachChipComesFreeAndLandsWithTheLast() {
        let plan = FilterFanPlan(widths: [60, 80, 70, 90, 75], selected: 0, isOpen: true)
        let unfold = HapticPatterns.fanUnfold(releases: plan.releaseTimes)
        #expect(unfold.count == 4, "One tick for each hidden chip")
        #expect(zip(unfold, unfold.dropFirst()).allSatisfy { $0.time < $1.time && $0.intensity > $1.intensity })
        #expect(unfold.allSatisfy { $0.duration == nil && (0...1).contains($0.intensity) })

        var folded = plan
        folded.isOpen = false
        folded.selected = 3
        let fold = HapticPatterns.fanFold(landing: folded.foldLanding)
        #expect(fold.first?.time == 0, "A tap on the touch")
        #expect(fold.last?.time == folded.foldLanding, "The firm tap as the last chip lands")
        #expect((fold.last?.intensity ?? 0) > (fold.first?.intensity ?? 1))
    }
}
