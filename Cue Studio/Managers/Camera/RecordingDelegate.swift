//
//  RecordingDelegate.swift
//  Cue Studio
//

import AVFoundation
import Synchronization

/// Bridges the movie output's delegate callback to async/await. The callback can arrive before or
/// after someone starts waiting (a recording can also end on its own, e.g. when storage fills up).
nonisolated final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, Sendable {
    private struct State {
        var continuation: CheckedContinuation<RecordedClip?, Never>?
        var finished = false
        var clip: RecordedClip?
    }

    private let state = Mutex(State())

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        // Some errors still leave a complete, playable file.
        let finishedAnyway = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
        let clip = (error == nil || finishedAnyway)
            ? RecordedClip(url: outputFileURL, duration: output.recordedDuration.seconds)
            : nil
        let waiting = state.withLock { state -> CheckedContinuation<RecordedClip?, Never>? in
            state.finished = true
            state.clip = clip
            defer { state.continuation = nil }
            return state.continuation
        }
        waiting?.resume(returning: clip)
    }

    /// Returns when the file is finalized.
    func waitUntilFinished() async -> RecordedClip? {
        await withCheckedContinuation { continuation in
            let result = state.withLock { state -> RecordedClip?? in
                if state.finished { return .some(state.clip) }
                state.continuation = continuation
                return .none
            }
            if case .some(let clip) = result {
                continuation.resume(returning: clip)
            }
        }
    }
}
