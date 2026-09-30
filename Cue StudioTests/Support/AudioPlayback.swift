//
//  AudioPlayback.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Synchronization

/// Feeds a fixture's buffers to `receive` in real time on a thread of its own, the way the capture
/// session's audio queue does: each buffer arrives once the time it covers has passed.
nonisolated final class AudioPlayback: Sendable {
    private let buffers: [SpeechFixture.SendableBuffer]
    private let bufferDuration: TimeInterval
    private let receive: @Sendable (AVAudioPCMBuffer) -> Void
    private let finished = Mutex(false)
    private let callbacks = Mutex<[TimeInterval]>([])

    var isFinished: Bool { finished.withLock { $0 } }

    /// How long each hand-over took on the audio thread: what the app does before it gives the
    /// thread back.
    var callbackDurations: [TimeInterval] { callbacks.withLock { $0 } }

    init(_ fixture: SpeechFixture, receive: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        buffers = fixture.buffers
        bufferDuration = fixture.bufferDuration
        self.receive = receive
    }

    /// Starts feeding. Returns the uptime at which the first buffer's audio begins.
    func start() -> TimeInterval {
        let start = ProcessInfo.processInfo.systemUptime + 0.05
        let thread = Thread { [self] in
            for (index, item) in buffers.enumerated() {
                let due = start + Double(index + 1) * bufferDuration
                let wait = due - ProcessInfo.processInfo.systemUptime
                if wait > 0 { Thread.sleep(forTimeInterval: wait) }
                let before = ProcessInfo.processInfo.systemUptime
                receive(item.buffer)
                let took = ProcessInfo.processInfo.systemUptime - before
                callbacks.withLock { $0.append(took) }
            }
            finished.withLock { $0 = true }
        }
        thread.qualityOfService = .userInteractive
        thread.start()
        return start
    }
}
