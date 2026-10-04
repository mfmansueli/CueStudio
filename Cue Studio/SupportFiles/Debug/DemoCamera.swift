//
//  DemoCamera.swift
//  Cue Studio
//

#if DEBUG
import AVFoundation

/// A camera that "records" with no hardware (`-uiTestDemoCamera`): it is running at once, a take lasts as long as it is held and ends as
/// a small real video, so UI tests can record, stop and review in the Simulator, which has no camera. Never shipped.
@MainActor
final class DemoCamera: CameraControlling {
    var status: CameraStatus = .running
    private(set) var isRecording = false
    private(set) var activeLens: CameraLens?
    var background = BackgroundEffect()
    var onRecordingEnded: (@MainActor (RecordedClip?, RecordingEndReason) -> Void)?
    private var startedAt: Date?

    func start(with settings: CameraSettings) async { activeLens = settings.lens }

    func apply(_ settings: CameraSettings) async { activeLens = settings.lens }

    func stop() async {}

    func startRecording(settings: CameraSettings) async throws {
        isRecording = true
        startedAt = .now
    }

    func stopRecording() async -> RecordedClip? {
        isRecording = false
        let seconds = max(2, Date.now.timeIntervalSince(startedAt ?? .now))
        let url = URL.temporaryDirectory.appending(path: "demo-take-\(UUID().uuidString).mov")
        SampleVideo.write(to: url, seconds: 2)
        return RecordedClip(url: url, duration: seconds)
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {}

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {}
}
#endif
