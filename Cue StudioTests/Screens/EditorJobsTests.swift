//
//  EditorJobsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's jobs: one of each kind at a time (a new one cancels the one before and its result stops counting), tools'
/// work side by side, and closing cancels everything and starts nothing.
@MainActor
@Suite("Editor jobs")
struct EditorJobsTests {
    /// Work that waits until cancelled, then says it was.
    private static func waitForCancel(_ cancelled: @escaping @MainActor () -> Void) -> @MainActor (EditorJobs.Ticket) async -> Void {
        { _ in
            try? await Task.sleep(for: .seconds(30))
            if Task.isCancelled { cancelled() }
        }
    }

    @Test func aNewJobOfTheSameKindReplacesTheOldOne() async {
        let jobs = EditorJobs()
        var cancelled = 0
        let first = jobs.start(.auto, Self.waitForCancel { cancelled += 1 })
        let second = jobs.start(.auto) { _ in }
        #expect(first != nil && second != nil)
        #expect(!jobs.isCurrent(first!))
        #expect(jobs.isCurrent(second!))
        await Wait.until { cancelled == 1 }
        await Wait.until { !jobs.isRunning(.auto) }
        // Finished: its result no longer counts either.
        #expect(!jobs.isCurrent(second!))
    }

    @Test func toolsRunSideBySideAndClosingCancelsEverything() async {
        let jobs = EditorJobs()
        var cancelled = 0
        jobs.start(.captions, Self.waitForCancel { cancelled += 1 })
        jobs.start(.beats("a.m4a"), Self.waitForCancel { cancelled += 1 })
        jobs.start(.beats("b.m4a"), Self.waitForCancel { cancelled += 1 })
        let tool = jobs.start(.tool(UUID()), Self.waitForCancel { cancelled += 1 })
        jobs.start(.tool(UUID()), Self.waitForCancel { cancelled += 1 })
        #expect(jobs.isCurrent(tool!))
        jobs.close()
        await Wait.until { cancelled == 5 }
        #expect(jobs.isClosed)
        #expect(!jobs.isCurrent(tool!))
        var ran = false
        #expect(jobs.start(.draft) { _ in ran = true } == nil)
        for _ in 0..<5 { await Task.yield() }
        #expect(!ran)
    }

    @Test func whatAJobMakesAsItIsCancelledIsDiscarded() async {
        let jobs = EditorJobs()
        let kind = EditorJobs.Kind.importing(UUID())
        var discarded: [Int] = []
        var thrown: (any Error)?
        let running = Task {
            do {
                // Work that finishes whatever happens (a file already copied).
                _ = try await jobs.run(kind, discard: { discarded.append($0) }, work: {
                    try? await Task.sleep(for: .milliseconds(50))
                    return 42
                })
            } catch {
                thrown = error
            }
        }
        await Wait.until { jobs.isRunning(kind) }
        jobs.close()
        await running.value
        #expect(thrown is CancellationError)
        #expect(discarded == [42])
    }

    @Test func cancellingOneKindLeavesTheOthers() async {
        let jobs = EditorJobs()
        var cancelled: [String] = []
        let tracking = jobs.start(.tracking, Self.waitForCancel { cancelled.append("tracking") })
        let cover = jobs.start(.cover, Self.waitForCancel { cancelled.append("cover") })
        jobs.cancel(.tracking)
        #expect(!jobs.isCurrent(tracking!))
        #expect(jobs.isCurrent(cover!))
        await Wait.until { cancelled == ["tracking"] }
        jobs.close()
    }
}
