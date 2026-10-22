//
//  BackgroundExportRunner.swift
//  Cue Studio
//

import Synchronization

/// Runs exports so they survive the creator leaving Cue. iOS is asked for a continued task with the GPU (Cue's frames are
/// drawn on it): when it takes it, the export goes on in another app with its progress in a Live Activity, and if iOS ends
/// it early the work is cancelled and `BackgroundExportError.stoppedBySystem` says so. When iOS doesn't take it (no
/// background GPU on this iPhone, busy, background activity off), the export runs as before, with the few seconds iOS gives
/// an app that leaves: Cue has to stay open.
@MainActor
final class BackgroundExportRunner: BackgroundExportRunning {
    private let scheduler: ContinuedTaskScheduling?
    /// The few seconds iOS gives an app that leaves (`beginBackgroundTask`); returns what ends them.
    private let shortGrace: @MainActor () -> @MainActor () -> Void

    init(
        scheduler: ContinuedTaskScheduling?,
        shortGrace: @escaping @MainActor () -> @MainActor () -> Void = BackgroundExportRunner.applicationGrace
    ) {
        self.scheduler = scheduler
        self.shortGrace = shortGrace
    }

    func run<Value: Sendable>(
        title: String,
        subtitle: String,
        started: @MainActor (BackgroundExportMode) -> Void,
        work: @escaping @MainActor (_ progress: @escaping @MainActor (Double) -> Void) async throws -> Value
    ) async throws -> Value {
        // Never without the GPU: measured on an iPhone 15 Pro (no background GPU), a task on the CPU alone kept Cue awake while
        // the frames stopped being drawn, and the export never ended; without a task it went on for as long as iOS let it.
        if let scheduler, scheduler.supportsBackgroundGPU, let task = await scheduler.start(title: title, subtitle: subtitle, gpu: true) {
            started(.continuesOutside)
            return try await run(work, in: task)
        }
        started(.staysInCue)
        let endGrace = shortGrace()
        defer { endGrace() }
        return try await work { _ in }
    }

    private func run<Value: Sendable>(
        _ work: @escaping @MainActor (_ progress: @escaping @MainActor (Double) -> Void) async throws -> Value,
        in task: ContinuedTaskHandle
    ) async throws -> Value {
        let expired = Mutex(false)
        let job = Task { @MainActor in
            try await work { task.report(min(max($0, 0), 1)) }
        }
        task.onExpiration {
            expired.withLock { $0 = true }
            job.cancel()
        }
        do {
            let value = try await withTaskCancellationHandler { try await job.value } onCancel: { job.cancel() }
            task.report(1)
            task.finish(success: true)
            return value
        } catch {
            task.finish(success: false)
            if expired.withLock({ $0 }) { throw BackgroundExportError.stoppedBySystem }
            throw error
        }
    }

    /// `beginBackgroundTask` (`ApplicationGrace`), ended by whoever comes first: the export, or iOS when the time is up.
    static func applicationGrace() -> @MainActor () -> Void {
        ApplicationGrace.begin(named: "Cue export")
    }
}
