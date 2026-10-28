//
//  AIRequestDeadline.swift
//  Cue Studio
//

import Foundation

/// Bounds capability lookups even if the framework doesn't finish when cancelled. The losing task
/// is cancelled without making the caller wait for it; the mutex resumes the continuation once.
nonisolated enum AIRequestDeadline {
    static func value<Value: Sendable>(
        within duration: Duration, operation: @escaping @Sendable () async -> Value
    ) async -> Value? {
        guard !Task.isCancelled else { return nil }
        let gate = AIRequestGate<Value>()
        let work = Task { gate.finish(await operation()) }
        let timer = Task {
            do { try await Task.sleep(for: duration) } catch { return }
            gate.finish(nil)
        }
        defer {
            work.cancel()
            timer.cancel()
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { gate.install($0) }
        } onCancel: {
            gate.finish(nil)
        }
    }

}
