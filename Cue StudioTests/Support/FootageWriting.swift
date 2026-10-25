//
//  FootageWriting.swift
//  Cue StudioTests
//

import Foundation
import Synchronization

/// AVAssetWriter in the simulator now and then stops taking a test's frames, with no error: the append waits for good and a
/// real export test runs into its time limit, while it passes in seconds on its own (25/10: the split screen's preview test and
/// the logo over three videos stopped while their footage was being written). A test video is written with a deadline: one
/// that sticks is left behind and written again.
enum FootageWriting {
    struct Stuck: Error {}

    /// What `write` makes, or, when it hasn't made it within `patience`, what a new try makes (at most `attempts`).
    static func withRetry(
        attempts: Int = 3, patience: Duration, _ write: @escaping @Sendable () async throws -> URL
    ) async throws -> URL {
        for _ in 0..<attempts {
            let task = Task { try await write() }
            if let url = try await value(of: task, within: patience) { return url }
            task.cancel()
        }
        throw Stuck()
    }

    /// The task's file, or nil when it isn't there within `patience` (the task may still be stuck: it is left behind).
    private static func value(of task: Task<URL, any Error>, within patience: Duration) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            let race = Race(continuation)
            Task {
                do { race.finish(.success(try await task.value)) } catch { race.finish(.failure(error)) }
            }
            Task {
                try? await Task.sleep(for: patience)
                race.finish(.success(nil))
            }
        }
    }

    /// Whichever comes first, the file or the deadline, resumes the wait; the other is let go.
    private final class Race: Sendable {
        private let waiting: Mutex<CheckedContinuation<URL?, any Error>?>

        init(_ continuation: CheckedContinuation<URL?, any Error>) {
            waiting = Mutex(continuation)
        }

        func finish(_ result: Result<URL?, any Error>) {
            let continuation = waiting.withLock { waiting in
                defer { waiting = nil }
                return waiting
            }
            continuation?.resume(with: result)
        }
    }
}
