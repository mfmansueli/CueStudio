//
//  PromptCardStarTwinkleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
struct PromptCardStarTwinkleTests {
    @Test func twinklesOnlyTheScheduledStar() {
        let time = 0.63 + 1.15 / 2

        #expect(PromptCardStarTwinkle.TwinkleSchedule.progress(for: .large, at: time) > 0.99)
        #expect(PromptCardStarTwinkle.TwinkleSchedule.progress(for: .small, at: time) == 0)
        #expect(PromptCardStarTwinkle.TwinkleSchedule.progress(for: .medium, at: time) == 0)
    }

    @Test func scheduleLeavesQuietGapsBetweenTwinkles() {
        let firstEventEnd = 0.63 + 1.15
        let quietTime = firstEventEnd + 0.5

        #expect(PromptCardStarTwinkle.TwinkleSchedule.progress(for: .large, at: quietTime) == 0)
        #expect(PromptCardStarTwinkle.TwinkleSchedule.progress(for: .small, at: quietTime) == 0)
        #expect(PromptCardStarTwinkle.TwinkleSchedule.progress(for: .medium, at: quietTime) == 0)
    }

    @Test func scheduleRepeatsWithoutChangingTheStarLayout() {
        let time = 9.38 + 1.0 / 2
        let repeatedTime = time + PromptCardStarTwinkle.TwinkleSchedule.cycleDuration

        #expect(
            PromptCardStarTwinkle.TwinkleSchedule.progress(for: .large, at: time)
                == PromptCardStarTwinkle.TwinkleSchedule.progress(for: .large, at: repeatedTime)
        )
    }

    @Test func twinklesNeverOverlapIncludingAcrossTheCycleBoundary() {
        let events = PromptCardStarTwinkle.TwinkleSchedule.events
        for (event, next) in zip(events, events.dropFirst()) {
            #expect(event.start + event.duration < next.start)
        }
        if let first = events.first, let last = events.last {
            #expect(last.start + last.duration < PromptCardStarTwinkle.TwinkleSchedule.cycleDuration + first.start)
        }
    }
}
