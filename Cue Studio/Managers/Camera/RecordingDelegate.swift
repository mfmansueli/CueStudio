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
        /// `stopRecording` was asked for: the end is expected.
        var stopRequested = false
        var onEndedByItself: (@Sendable (RecordedClip?, RecordingEndReason) -> Void)?
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
        typealias Ended = @Sendable (RecordedClip?, RecordingEndReason) -> Void
        let (waiting, endedByItself) = state.withLock { state -> (CheckedContinuation<RecordedClip?, Never>?, Ended?) in
            state.finished = true
            state.clip = clip
            defer { state.continuation = nil }
            return (state.continuation, state.stopRequested ? nil : state.onEndedByItself)
        }
        waiting?.resume(returning: clip)
        // The system ended it (storage full, an interruption): tell the recorder so it can save the take.
        endedByItself?(clip, RecordingEndReason(error: error))
    }

    /// The creator stopped the take: its end is expected.
    func markStopRequested() {
        state.withLock { $0.stopRequested = true }
    }

    /// Called when the take ends without a stop (storage full, a call).
    func setEndedByItself(_ handler: (@Sendable (RecordedClip?, RecordingEndReason) -> Void)?) {
        state.withLock { $0.onEndedByItself = handler }
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
