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

    /// The background effect for this session's takes.
    private(set) var background = BackgroundEffect()
    /// The camera's frames with the effect, for the preview; nil when off or not drawn yet.
    private(set) var backgroundFrame: CGImage?
    /// Whether this camera can give frames for the live preview next to the recording.
    private(set) var showsBackgroundLive = true

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
            // A background chosen before the camera ran shows now.
            if background.isActive { await showBackground() }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func apply(_ settings: CameraSettings) async {
        guard status == .running, !isRecording else { return }
        let lens = activeLens
        activeLens = await engine.apply(settings: settings)
        activeDeviceID = await engine.activeDeviceID
        // The front camera's preview is mirrored; the effect's frames follow.
        if activeLens != lens, background.isActive { await showBackground() }
    }

    /// Sets the background for the next takes and starts (or stops) its live preview. Not while
    /// recording: the take keeps what it started with.
    func setBackground(_ effect: BackgroundEffect) async {
        guard !isRecording else { return }
        background = effect
        await showBackground()
    }

    private func showBackground() async {
        let render = status == .running ? BackgroundRender.prepare(background, cacheKey: "live") : nil
        if render == nil { backgroundFrame = nil }
        var handler: (@Sendable (CGImage) -> Void)?
        if render != nil {
            handler = { [weak self] frame in
                Task { @MainActor [weak self] in
                    guard let self, self.background.isActive else { return }
                    self.backgroundFrame = frame
                }
            }
        }
        showsBackgroundLive = await engine.setBackgroundPreview(render, mirrored: activeLens == .front, handler: handler)
    }

    func stop() async {
        if isRecording { _ = await stopRecording() }
        _ = await engine.setBackgroundPreview(nil, mirrored: false, handler: nil)
        backgroundFrame = nil
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

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        engine.setAudioHandler(handler)
    }

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {
        engine.setLevelHandler(handler)
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
