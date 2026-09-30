//
//  PromptBackgroundClockTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
struct PromptBackgroundClockTests {
    @Test func pausesWithoutAdvancingAndResumesFromTheSameFrame() {
        var clock = AnimatedPromptBackground.MotionClock()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        clock.setRunning(true, at: start)
        clock.setRunning(false, at: start.addingTimeInterval(7))
        #expect(clock.elapsed(at: start.addingTimeInterval(120)) == 7)

        clock.setRunning(true, at: start.addingTimeInterval(120))
        #expect(clock.elapsed(at: start.addingTimeInterval(120)) == 7)
        #expect(clock.elapsed(at: start.addingTimeInterval(123)) == 10)
    }

    @Test func repeatedVisibilityNotificationsDoNotRestartMotion() {
        var clock = AnimatedPromptBackground.MotionClock()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(clock.elapsed(at: start) == 0)
        clock.setRunning(true, at: start)
        clock.setRunning(true, at: start.addingTimeInterval(4))
        #expect(clock.elapsed(at: start.addingTimeInterval(7)) == 7)

        clock.setRunning(false, at: start.addingTimeInterval(7))
        clock.setRunning(false, at: start.addingTimeInterval(90))
        #expect(clock.elapsed(at: start.addingTimeInterval(120)) == 7)
    }
}
