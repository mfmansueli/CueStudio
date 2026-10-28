//
//  AIRequestDeadlineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("AI capability deadline")
struct AIRequestDeadlineTests {
    private actor Probe {
        var finished = false
        func finish() { finished = true }
    }

    @Test func aLookupThatIgnoresCancellationCannotHoldTheCaller() async {
        let probe = Probe()
        let result = await AIRequestDeadline.value(within: .milliseconds(10)) {
            await withCheckedContinuation { continuation in
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await probe.finish()
                    continuation.resume(returning: true)
                }
            }
        }
        #expect(result == nil)
        #expect(await !probe.finished, "the deadline must return before the non-cooperative lookup finishes")
    }

    @Test func cancellationReturnsWithoutWaitingForTheDeadline() async {
        let task = Task {
            await AIRequestDeadline.value(within: .seconds(60)) {
                try? await Task.sleep(for: .seconds(60))
                return true
            }
        }
        task.cancel()
        #expect(await task.value == nil)
    }

    @Test func aCompletedLookupReturnsItsAnswer() async {
        #expect(await AIRequestDeadline.value(within: .seconds(1)) { 42 } == 42)
    }
}
