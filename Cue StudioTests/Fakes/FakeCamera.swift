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
    /// Nil until started; then the lens asked for, unless a test says this device lacks it.
    var activeLens: CameraLens?
    var background = BackgroundEffect()
    var missingLenses: Set<CameraLens> = []
    var failsToRecord = false
    var clipDuration: TimeInterval = 42
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var appliedSettings: [CameraSettings] = []
    private(set) var startedSettings: [CameraSettings] = []
    private(set) var recordedSettings: [CameraSettings] = []
    private(set) var recordingsStarted = 0
    private(set) var audioHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private(set) var levelHandler: (@Sendable (AudioLevelSample) -> Void)?

    func start(with settings: CameraSettings) async {
        startCount += 1
        startedSettings.append(settings)
        useLens(settings.lens)
    }

    func apply(_ settings: CameraSettings) async {
        appliedSettings.append(settings)
        useLens(settings.lens)
    }

    /// Like the capture engine: a lens this device lacks falls back to the front camera.
    private func useLens(_ lens: CameraLens) {
        activeLens = missingLenses.contains(lens) ? .front : lens
    }

    func stop() async {
        stopCount += 1
    }

    func startRecording(settings: CameraSettings) async throws {
        if failsToRecord { throw CaptureEngineError.notRunning }
        recordingsStarted += 1
        recordedSettings.append(settings)
        isRecording = true
    }

    func stopRecording() async -> RecordedClip? {
        isRecording = false
        let url = URL.temporaryDirectory.appending(path: "fake-take-\(UUID().uuidString).mov")
        return RecordedClip(url: url, duration: clipDuration)
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        audioHandler = handler
    }

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {
        levelHandler = handler
    }

    /// A microphone buffer `duration` long at `level` dBFS, arriving at `time`.
    func hear(level: Float, at time: TimeInterval, duration: TimeInterval = 1024.0 / 48_000) {
        levelHandler?(AudioLevelSample(level: level, time: time, duration: duration))
    }
}
