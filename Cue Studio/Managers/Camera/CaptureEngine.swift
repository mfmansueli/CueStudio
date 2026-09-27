//
//  CaptureEngine.swift
//  Cue Studio
//

import AVFoundation

/// Owns the capture session. Runs on its own serial queue (the actor's executor) because starting
/// and configuring a session blocks, and must never happen on the main thread.
actor CaptureEngine {
    nonisolated let session = AVCaptureSession()

    private let queue = DispatchSerialQueue(label: "studio.cue.capture")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let movieOutput = AVCaptureMovieFileOutput()
    /// Hands the microphone audio to Voice follow's speech recognition while it listens. Sits next
    /// to the movie output (both may be active together since iOS 16).
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let audioTap = AudioBufferTap()
    private let audioQueue = DispatchSerialQueue(label: "studio.cue.capture.audio")
    private var videoInput: AVCaptureDeviceInput?
    private var activeLens: CameraLens?
    private var isConfigured = false
    private var recordingDelegate: RecordingDelegate?

    var isRecording: Bool { movieOutput.isRecording }

    /// Unique ID of the camera in use, for the preview's rotation coordinator.
    var activeDeviceID: String? { videoInput?.device.uniqueID }

    // MARK: - Devices

    func availableLenses() -> [CameraLens] {
        CameraLens.allCases.filter { Self.device(for: $0) != nil }
    }

    private static func device(for lens: CameraLens) -> AVCaptureDevice? {
        switch lens {
        case .front: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        case .wide: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .ultraWide: AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        case .telephoto: AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        }
    }

    // MARK: - Session

    /// Configures inputs and outputs and starts the session. Returns the lens actually in use.
    func start(settings: CameraSettings, includeAudio: Bool) throws -> CameraLens {
        session.beginConfiguration()
        if !isConfigured {
            session.sessionPreset = .high
            if includeAudio,
               let microphone = AVCaptureDevice.default(for: .audio),
               let input = try? AVCaptureDeviceInput(device: microphone),
               session.canAddInput(input) {
                session.addInput(input)
                if session.canAddOutput(audioDataOutput) {
                    audioDataOutput.setSampleBufferDelegate(audioTap, queue: audioQueue)
                    session.addOutput(audioDataOutput)
                }
            }
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }
            isConfigured = true
        }
        let lens: CameraLens
        do {
            lens = try useLens(settings.lens)
        } catch {
            session.commitConfiguration()
            throw error
        }
        configureFormat(settings)
        configureConnection(settings)
        session.commitConfiguration()
        if !session.isRunning {
            session.startRunning()
        }
        return lens
    }

    /// Applies changed settings to the running session. Returns the lens in use.
    func apply(settings: CameraSettings) -> CameraLens? {
        guard isConfigured, !movieOutput.isRecording else { return activeLens }
        session.beginConfiguration()
        _ = try? useLens(settings.lens)
        configureFormat(settings)
        configureConnection(settings)
        session.commitConfiguration()
        return activeLens
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    /// Switches the video input, falling back to any available camera.
    private func useLens(_ lens: CameraLens) throws -> CameraLens {
        let target = Self.device(for: lens) != nil ? lens : (availableLenses().first ?? lens)
        if target == activeLens, videoInput != nil { return target }
        guard let device = Self.device(for: target) else { throw CaptureEngineError.noCamera }
        let input = try AVCaptureDeviceInput(device: device)
        if let videoInput { session.removeInput(videoInput) }
        guard session.canAddInput(input) else {
            if let videoInput { session.addInput(videoInput) }
            throw CaptureEngineError.cannotUseCamera
        }
        session.addInput(input)
        videoInput = input
        activeLens = target
        return target
    }

    private func configureFormat(_ settings: CameraSettings) {
        guard let device = videoInput?.device else { return }
        let candidates = device.formats.map { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let subtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            return CaptureFormatCandidate(
                width: Int(dimensions.width),
                height: Int(dimensions.height),
                maxFrameRate: format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0,
                isStandardPixelFormat: subtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                    || subtype == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            )
        }
        guard let index = CaptureFormatSelector.bestIndex(in: candidates, resolution: settings.resolution, frameRate: settings.frameRate) else { return }
        let format = device.formats[index]
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate.rawValue))
        do {
            try device.lockForConfiguration()
            if device.activeFormat != format { device.activeFormat = format }
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            device.unlockForConfiguration()
        } catch {
            // The previous format keeps working; nothing else to do.
        }
    }

    private func configureConnection(_ settings: CameraSettings) {
        guard let connection = movieOutput.connection(with: .video) else { return }
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = settings.stabilization ? .auto : .off
        }
        let codec: AVVideoCodecType = settings.codec == .hevc ? .hevc : .h264
        if movieOutput.availableVideoCodecTypes.contains(codec) {
            movieOutput.setOutputSettings([AVVideoCodecKey: codec], for: connection)
        }
    }

    // MARK: - Recording

    func startRecording(to url: URL, rotationAngle: CGFloat) throws {
        guard !movieOutput.isRecording else { return }
        guard let connection = movieOutput.connection(with: .video), connection.isActive else {
            throw CaptureEngineError.notRunning
        }
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
        let delegate = RecordingDelegate()
        recordingDelegate = delegate
        movieOutput.startRecording(to: url, recordingDelegate: delegate)
    }

    func stopRecording() async -> RecordedClip? {
        guard let delegate = recordingDelegate else { return nil }
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        let clip = await delegate.waitUntilFinished()
        recordingDelegate = nil
        return clip
    }

    /// Average power of the recorded audio in dBFS.
    func audioPowerLevel() -> Float? {
        movieOutput.connection(with: .audio)?.audioChannels.first?.averagePowerLevel
    }

    /// Sends the microphone audio to `handler` on the capture audio queue. Nil stops it.
    nonisolated func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        audioTap.setHandler(handler)
    }
}
