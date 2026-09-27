//
//  CameraManager.swift
//  Cue Studio
//

import AVFoundation

/// The camera, as screens see it: status, lenses and recording. The heavy lifting happens in
/// `CaptureEngine`, off the main thread.
@MainActor
@Observable
final class CameraManager: CameraControlling {
    private(set) var status: CameraStatus = .idle
    private(set) var isRecording = false
    private(set) var availableLenses: [CameraLens] = []
    private(set) var activeLens: CameraLens?
    /// Unique ID of the camera in use.
    private(set) var activeDeviceID: String?

    /// Rotation for recorded video, kept current by the preview's rotation coordinator.
    var captureRotationAngle: CGFloat = 90

    private let engine = CaptureEngine()

    /// For the preview layer only.
    var previewSession: AVCaptureSession { engine.session }

    // MARK: - Session

    func start(with settings: CameraSettings) async {
        switch status {
        case .running:
            await apply(settings)
            return
        case .starting:
            return
        default:
            break
        }
        status = .starting
        // No point asking for permission on a device without a camera.
        availableLenses = await engine.availableLenses()
        guard !availableLenses.isEmpty else {
            status = .unavailable
            return
        }
        guard await Self.requestAccess(for: .video) else {
            status = .unauthorized
            return
        }
        let hasAudio = await Self.requestAccess(for: .audio)
        do {
            activeLens = try await engine.start(settings: settings, includeAudio: hasAudio)
            activeDeviceID = await engine.activeDeviceID
            status = .running
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func apply(_ settings: CameraSettings) async {
        guard status == .running, !isRecording else { return }
        activeLens = await engine.apply(settings: settings)
        activeDeviceID = await engine.activeDeviceID
    }

    func stop() async {
        if isRecording { _ = await stopRecording() }
        await engine.stop()
        if status == .running || status == .starting { status = .idle }
    }

    // MARK: - Recording

    func startRecording(settings: CameraSettings) async throws {
        let url = URL.temporaryDirectory.appending(path: "take-\(UUID().uuidString).mov")
        try await engine.startRecording(to: url, rotationAngle: captureRotationAngle)
        isRecording = true
    }

    func stopRecording() async -> RecordedClip? {
        let clip = await engine.stopRecording()
        isRecording = false
        return clip
    }

    func audioPowerLevel() async -> Float? {
        await engine.audioPowerLevel()
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        engine.setAudioHandler(handler)
    }

    // MARK: - Permissions

    private static func requestAccess(for media: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: media)
        default: false
        }
    }
}
