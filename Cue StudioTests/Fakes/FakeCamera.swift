//
//  FakeCamera.swift
//  Cue StudioTests
//

import AVFAudio
@testable import Cue_Studio

@MainActor
final class FakeCamera: CameraControlling {
    var status: CameraStatus = .running
    private(set) var isRecording = false
    var audioLevel: Float?
    var failsToRecord = false
    var clipDuration: TimeInterval = 42
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var appliedSettings: [CameraSettings] = []
    private(set) var recordingsStarted = 0
    private(set) var audioHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?

    func start(with settings: CameraSettings) async {
        startCount += 1
    }

    func apply(_ settings: CameraSettings) async {
        appliedSettings.append(settings)
    }

    func stop() async {
        stopCount += 1
    }

    func startRecording(settings: CameraSettings) async throws {
        if failsToRecord { throw CaptureEngineError.notRunning }
        recordingsStarted += 1
        isRecording = true
    }

    func stopRecording() async -> RecordedClip? {
        isRecording = false
        let url = URL.temporaryDirectory.appending(path: "fake-take-\(UUID().uuidString).mov")
        return RecordedClip(url: url, duration: clipDuration)
    }

    func audioPowerLevel() async -> Float? { audioLevel }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        audioHandler = handler
    }
}
