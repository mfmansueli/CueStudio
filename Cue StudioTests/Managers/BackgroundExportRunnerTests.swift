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

    /// What the screen's auto-lock was told, in order (true: held off).
    private final class AutoLock {
        var applied: [Bool] = []
    }

    private func runner(
        _ scheduler: FakeContinuedTaskScheduler?, grace: Grace = Grace(), screen: ScreenAwake = ScreenAwake { _ in }
    ) -> BackgroundExportRunner {
        BackgroundExportRunner(scheduler: scheduler, screenAwake: screen) {
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

    // MARK: - Auto-lock

    /// Cue has to stay open: the iPhone doesn't lock by itself while the work runs, and locks again once it ends, done, failed or
    /// cancelled.
    @Test(arguments: ["done", "failed", "cancelled"])
    func keepingCueOpenHoldsAutoLockOffUntilTheWorkEnds(ending: String) async throws {
        let scheduler = FakeContinuedTaskScheduler()
        scheduler.supportsBackgroundGPU = false
        let lock = AutoLock()
        let screen = ScreenAwake { lock.applied.append($0) }
        var heldWhileWorking = false
        let running = Task { @MainActor in
            try await runner(scheduler, screen: screen).run(title: "t", subtitle: "s", started: { _ in }, work: { _ -> Int in
                heldWhileWorking = screen.isHeld
                switch ending {
                case "failed": throw VideoExportError.exportUnavailable
                case "cancelled":
                    try await Task.sleep(for: .seconds(10))
                    return 0
                default: return 1
                }
            })
        }
        if ending == "cancelled" {
            while !heldWhileWorking { await Task.yield() }
            running.cancel()
        }
        _ = try? await running.value
        #expect(heldWhileWorking)
        #expect(lock.applied == [true, false])
        #expect(!screen.isHeld)
    }

    /// iOS carries the export outside Cue: the screen may lock as usual.
    @Test func goingOnOutsideCueLeavesAutoLockAlone() async throws {
        let lock = AutoLock()
        let screen = ScreenAwake { lock.applied.append($0) }
        _ = try await runner(FakeContinuedTaskScheduler(), screen: screen).run(title: "t", subtitle: "s", started: { _ in }, work: { _ in 1 })
        #expect(lock.applied.isEmpty)
    }

    /// The prompter (or the remote) holds the screen too: an export ending doesn't give auto-lock back under it, and the prompter
    /// closing doesn't give it back under a running export.
    @Test func anotherOwnerKeepsTheScreenOnAfterTheExportEnds() async throws {
        let scheduler = FakeContinuedTaskScheduler()
        scheduler.supportsBackgroundGPU = false
        let lock = AutoLock()
        let screen = ScreenAwake { lock.applied.append($0) }
        screen.hold("prompter")
        _ = try await runner(scheduler, screen: screen).run(title: "t", subtitle: "s", started: { _ in }, work: { _ in
            screen.release("prompter")
            #expect(screen.isHeld)
            return 1
        })
        #expect(lock.applied == [true, false])
        screen.hold("prompter")
        _ = try await runner(scheduler, screen: screen).run(title: "t", subtitle: "s", started: { _ in }, work: { _ in 1 })
        #expect(screen.isHeld)
        #expect(lock.applied == [true, false, true])
    }
}
