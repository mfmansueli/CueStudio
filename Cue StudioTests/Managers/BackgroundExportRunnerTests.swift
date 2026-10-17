//
//  BackgroundExportRunnerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Exports that go on outside Cue: iOS takes the task (with the GPU) and hears the progress; without the background GPU, or
/// when iOS refuses, the export runs as before inside the short grace iOS gives an app that leaves; iOS ending the task
/// cancels the work and says so; a failure of the work itself stays that failure.
@MainActor
@Suite("Background export runner")
struct BackgroundExportRunnerTests {
    private final class Grace {
        var begun = 0
        var ended = 0
    }

    private func runner(_ scheduler: FakeContinuedTaskScheduler?, grace: Grace = Grace()) -> BackgroundExportRunner {
        BackgroundExportRunner(scheduler: scheduler) {
            grace.begun += 1
            return { grace.ended += 1 }
        }
    }

    @Test func iOSTakesItAndHearsTheProgress() async throws {
        let scheduler = FakeContinuedTaskScheduler()
        let grace = Grace()
        var mode: BackgroundExportMode?
        let value = try await runner(scheduler, grace: grace).run(title: "Exporting your video", subtitle: "Take 3", started: { mode = $0 }, work: { report in
            report(0.25)
            report(0.8)
            return 7
        })
        #expect(value == 7)
        #expect(mode == .continuesOutside)
        #expect(scheduler.requests.map(\.subtitle) == ["Take 3"])
        #expect(scheduler.task?.reports == [0.25, 0.8, 1])
        #expect(scheduler.task?.finished == true)
        // No short grace on top of iOS's task.
        #expect(grace.begun == 0)
    }

    @Test func withoutTheBackgroundGPUCueStaysOpenAsBefore() async throws {
        let scheduler = FakeContinuedTaskScheduler()
        scheduler.supportsBackgroundGPU = false
        let grace = Grace()
        var mode: BackgroundExportMode?
        let value = try await runner(scheduler, grace: grace).run(title: "t", subtitle: "s", started: { mode = $0 }, work: { _ in "file" })
        #expect(value == "file")
        #expect(mode == .staysInCue)
        #expect(scheduler.requests.isEmpty)
        #expect(grace.begun == 1)
        #expect(grace.ended == 1)
    }

    @Test func refusedByIOSItRunsInsideCue() async throws {
        let scheduler = FakeContinuedTaskScheduler()
        scheduler.task = nil
        let grace = Grace()
        var mode: BackgroundExportMode?
        _ = try await runner(scheduler, grace: grace).run(title: "t", subtitle: "s", started: { mode = $0 }, work: { _ in true })
        #expect(mode == .staysInCue)
        #expect(scheduler.requests.count == 1)
        #expect(grace.ended == 1)
    }

    @Test func iOSEndingTheTaskCancelsTheWorkAndSaysSo() async throws {
        let scheduler = FakeContinuedTaskScheduler()
        let task = try #require(scheduler.task)
        var cancelled = false
        await #expect(throws: BackgroundExportError.stoppedBySystem) {
            _ = try await runner(scheduler).run(title: "t", subtitle: "s", started: { _ in }, work: { _ in
                task.expire()
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    cancelled = true
                    throw error
                }
                return 1
            })
        }
        #expect(cancelled)
        #expect(task.finished == false)
    }

    @Test func aFailureOfTheWorkStaysThatFailure() async throws {
        let scheduler = FakeContinuedTaskScheduler()
        await #expect(throws: VideoExportError.exportUnavailable) {
            _ = try await runner(scheduler).run(title: "t", subtitle: "s", started: { _ in }, work: { _ -> Int in
                throw VideoExportError.exportUnavailable
            })
        }
        #expect(scheduler.task?.finished == false)
    }
}
