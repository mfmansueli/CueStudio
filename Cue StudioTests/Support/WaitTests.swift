//
//  WaitTests.swift
//  Cue StudioTests
//

import Testing

/// `Wait.until` returns as soon as the condition holds, outlasts work that needs real time, and says so when it gives up.
@MainActor
@Suite("Wait")
struct WaitTests {
    /// Something a test is waiting for.
    @MainActor
    private final class Flag {
        var isUp = false
    }

    @Test func aConditionThatAlreadyHoldsReturnsAtOnce() async {
        let start = ContinuousClock.now
        #expect(await Wait.until { true })
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    /// Work that sleeps outlasts any number of yields: the wait goes on by the clock.
    @Test func workThatTakesRealTimeIsWaitedFor() async {
        let flag = Flag()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            flag.isUp = true
        }
        #expect(await Wait.until { flag.isUp })
    }

    @Test func aConditionThatNeverHoldsIsRecordedAtTheTimeout() async {
        var waited = true
        await withKnownIssue {
            waited = await Wait.until(timeout: .milliseconds(50)) { false }
        }
        #expect(!waited)
    }
}
