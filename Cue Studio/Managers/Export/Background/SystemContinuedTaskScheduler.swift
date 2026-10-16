//
//  SystemContinuedTaskScheduler.swift
//  Cue Studio
//

import BackgroundTasks
import OSLog
import Synchronization

/// iOS's continued-processing tasks (`BGContinuedProcessingTask`, iOS 26), the only file that talks to `BackgroundTasks`.
/// Each export gets its own identifier under `com.cuestudioteleprompter.export.*` (Info.plist), registered right before it
/// is submitted (continued tasks may be registered after launch; one identifier is never registered twice). The request
/// fails rather than queues (`.fail`): a queued export the creator can't see would be worse than one that waits in Cue.
@MainActor
final class SystemContinuedTaskScheduler: ContinuedTaskScheduling {
    /// How long iOS has to start a task it accepted before Cue exports the usual way (some iOS 26 releases never call
    /// the handler).
    static let startTimeout: Duration = .seconds(5)

    private let logger = Logger(subsystem: "studio.cue", category: "BackgroundExport")
    private let prefix: String

    init(bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.cuestudioteleprompter") {
        prefix = "\(bundleIdentifier).export"
    }

    var supportsBackgroundGPU: Bool {
        BGTaskScheduler.supportedResources.contains(.gpu)
    }

    func start(title: String, subtitle: String) async -> ContinuedTaskHandle? {
        let identifier = "\(prefix).\(UUID().uuidString)"
        let signal = TaskStartSignal()
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            // Too late: Cue already exported the usual way.
            if !signal.deliver(StartedTask(task: task)) { task.setTaskCompleted(success: false) }
        }
        guard registered else {
            logger.error("Continued task not registered: \(identifier, privacy: .public) isn't permitted by Info.plist")
            return nil
        }
        do {
            try await Self.submit(identifier: identifier, title: title, subtitle: subtitle)
        } catch {
            logger.notice("Continued task refused: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let timeout = Task {
            try? await Task.sleep(for: Self.startTimeout)
            signal.deliver(nil)
        }
        defer { timeout.cancel() }
        guard let started = await signal.wait() else {
            logger.notice("Continued task not started within \(Self.startTimeout, privacy: .public): exporting in Cue")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return nil
        }
        logger.info("Continued task started with the GPU")
        return SystemContinuedTask(task: started.task)
    }

    /// The request, failing rather than queueing, with the GPU; submitted off the main thread, as iOS asks.
    @concurrent
    private nonisolated static func submit(identifier: String, title: String, subtitle: String) async throws {
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: title, subtitle: subtitle)
        request.strategy = .fail
        request.requiredResources = .gpu
        try await BGTaskScheduler.shared.submitTaskRequest(request)
    }

    /// A started task carried from the scheduler's queue to the main actor.
    private nonisolated struct StartedTask: @unchecked Sendable {
        let task: BGContinuedProcessingTask
    }

    /// The first of "iOS started the task" and "time's up", heard once.
    private nonisolated final class TaskStartSignal: Sendable {
        /// The outcome once decided (`.some(nil)`: time's up), and who waits for it.
        private let state = Mutex<(outcome: StartedTask??, waiting: CheckedContinuation<StartedTask?, Never>?)>((nil, nil))

        /// False when the outcome was already decided (the task came after the timeout).
        @discardableResult
        func deliver(_ task: StartedTask?) -> Bool {
            let (accepted, waiting) = state.withLock { state -> (Bool, CheckedContinuation<StartedTask?, Never>?) in
                guard state.outcome == nil else { return (false, nil) }
                state.outcome = .some(task)
                defer { state.waiting = nil }
                return (true, state.waiting)
            }
            waiting?.resume(returning: task)
            return accepted
        }

        func wait() async -> StartedTask? {
            await withCheckedContinuation { continuation in
                let decided = state.withLock { state -> StartedTask?? in
                    if let outcome = state.outcome { return .some(outcome) }
                    state.waiting = continuation
                    return nil
                }
                if let decided { continuation.resume(returning: decided) }
            }
        }
    }

    /// The task iOS runs: progress in thousandths, its end, and iOS ending it.
    @MainActor
    private final class SystemContinuedTask: ContinuedTaskHandle {
        private let task: BGContinuedProcessingTask

        init(task: BGContinuedProcessingTask) {
            self.task = task
            task.progress.totalUnitCount = 1000
        }

        func report(_ fraction: Double) {
            task.progress.completedUnitCount = Int64((fraction * 1000).rounded())
        }

        func onExpiration(_ handler: @escaping @Sendable () -> Void) {
            task.expirationHandler = handler
        }

        func finish(success: Bool) {
            task.setTaskCompleted(success: success)
        }
    }
}
