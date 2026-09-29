//
//  FakeVoiceRecorder.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A recorder that records nothing: `stop` hands back a made-up file of `length` seconds.
@MainActor
final class FakeVoiceRecorder: VoiceOverRecording {
    var isRecording = false
    var elapsed: TimeInterval = 0
    var allowed = true
    var length: TimeInterval = 4
    private(set) var cancelled = false

    func requestPermission() async -> Bool { allowed }

    func start() async throws {
        isRecording = true
    }

    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard isRecording else { return nil }
        isRecording = false
        return ("voice-\(UUID().uuidString).m4a", length)
    }

    func cancel() {
        isRecording = false
        cancelled = true
    }
}
