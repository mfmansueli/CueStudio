//
//  NarrationSpeechJob.swift
//  Cue Studio
//

import AVFoundation
import os

/// One text being said into a file: the synthesizer, the file it fills, and the wait for its end. The synthesizer hands the
/// sound over in buffers on a queue of its own, the last one empty; a cancel stops it at once.
nonisolated final class NarrationSpeechJob: @unchecked Sendable {
    private struct State {
        var file: AVAudioFile?
        var continuation: CheckedContinuation<Void, Error>?
        var isOver = false
        var failure: Error?
    }

    private let url: URL
    private let synthesizer = AVSpeechSynthesizer()
    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    init(url: URL) {
        self.url = url
    }

    func run(_ utterance: AVSpeechUtterance) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let cancelled = state.withLockUnchecked { state in
                state.continuation = continuation
                return state.isOver
            }
            guard !cancelled else {
                finish(throwing: CancellationError())
                return
            }
            synthesizer.write(utterance) { [self] buffer in receive(buffer) }
        }
    }

    func cancel() {
        synthesizer.stopSpeaking(at: .immediate)
        finish(throwing: CancellationError())
    }

    private func receive(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        guard pcm.frameLength > 0 else {
            let wrote = state.withLockUnchecked { $0.file != nil }
            finish(throwing: wrote ? nil : SystemNarrationSpeaker.SpeakError.nothingSaid)
            return
        }
        let failed: Bool = state.withLockUnchecked { state in
            guard !state.isOver else { return false }
            do {
                if state.file == nil {
                    state.file = try AVAudioFile(
                        forWriting: url, settings: pcm.format.settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved
                    )
                }
                try state.file?.write(from: pcm)
                return false
            } catch {
                state.failure = error
                return true
            }
        }
        if failed {
            synthesizer.stopSpeaking(at: .immediate)
            finish(throwing: SystemNarrationSpeaker.SpeakError.couldNotWrite)
        }
    }

    /// Ends the wait once (the file closed first); later calls do nothing.
    private func finish(throwing error: Error?) {
        let continuation: CheckedContinuation<Void, Error>? = state.withLockUnchecked { state in
            state.isOver = true
            state.file = nil
            defer { state.continuation = nil }
            return state.continuation
        }
        if let error { continuation?.resume(throwing: error) } else { continuation?.resume() }
    }
}
