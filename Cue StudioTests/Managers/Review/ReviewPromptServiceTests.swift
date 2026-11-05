//
//  ReviewPromptServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The rating prompt as the app keeps it: pending after a later day's second video, gone after a failure, asked once per version.
@MainActor
@Suite("Rating prompt")
struct ReviewPromptServiceTests {
    /// The day and the free exports left, changed as a test goes on.
    private final class Clock {
        var now = TestData.now
        var left: Int? = 2
    }

    @Test func itTurnsPendingOnALaterDayAndIsAskedOncePerVersion() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let clock = Clock()
        let prompt = ReviewPromptService(defaults: store.defaults, exportsLeft: { clock.left }, version: "1.0", now: { clock.now })
        prompt.delivered()
        clock.now = clock.now.addingTimeInterval(86_400)
        prompt.delivered()
        #expect(prompt.isPending)
        prompt.markAsked()
        #expect(!prompt.isPending)
        clock.left = 1
        prompt.delivered()
        #expect(!prompt.isPending)
        let reopened = ReviewPromptService(defaults: store.defaults, exportsLeft: { clock.left }, version: "1.0", now: { clock.now })
        reopened.delivered()
        #expect(!reopened.isPending)
    }

    @Test func aFailureThatDayKeepsItQuiet() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let clock = Clock()
        let prompt = ReviewPromptService(defaults: store.defaults, exportsLeft: { nil }, version: "1.0", now: { clock.now })
        prompt.delivered()
        clock.now = clock.now.addingTimeInterval(86_400)
        prompt.failed()
        prompt.delivered()
        #expect(!prompt.isPending)
    }
}
