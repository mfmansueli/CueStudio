//
//  AudioInputManager.swift
//  Cue Studio
//

import AVFAudio

/// The microphone: which inputs are connected, which one records (the pill on the recording
/// screen), and the live input for Voice follow in Studio mode, where the camera (and its own
/// audio) is off: the level, and the audio itself for speech recognition.
@MainActor
@Observable
final class AudioInputManager: AudioLevelMetering, MicrophoneListing {
    private(set) var inputs: [MicrophoneOption] = []
    /// The input the audio comes from right now. Nil until the audio session reports one.
    private(set) var currentInput: MicrophoneOption?
    /// The input picked in Audio Input (or Camera settings), while it's connected.
    private(set) var preferredInputID: String?
    /// False once the creator denied the microphone: takes are recorded without sound.
    private(set) var isMicrophoneAllowed = true

    /// What the recording screen names and the picker checks.
    var inputInUse: MicrophoneOption? {
        MicrophoneOption.inUse(current: currentInput, preferredID: preferredInputID, available: inputs)
    }

    private var engine: AVAudioEngine?
    private let tap = AudioBufferTap()
    @ObservationIgnored private var routeObserver: (any NSObjectProtocol)?

    // MARK: - Inputs

    /// Lists the inputs available now (built-in, wired, Bluetooth, USB).
    func refreshInputs() {
        AudioRoute.prepareToListInputs()
        readRoute()
    }

    /// Makes `id` the input to record from; nil returns to the system default. The camera applies
    /// the same choice from the settings whenever it starts.
    func select(_ id: String?) {
        AudioRoute.prefer(inputID: id)
        readRoute()
    }

    /// Keeps the inputs and the one in use current while the recording screen shows them: a mic
    /// plugged in or unplugged, AirPods connecting, the camera setting up the session. Calling it
    /// again reads the route again.
    func startObservingRoute() {
        readRoute()
        guard routeObserver == nil else { return }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.readRoute() }
        }
    }

    func stopObservingRoute() {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
        inputs = []
        currentInput = nil
        preferredInputID = nil
    }

    private func readRoute() {
        inputs = AudioRoute.availableInputs()
        currentInput = AudioRoute.currentInput()
        preferredInputID = AudioRoute.preferredInputID()
        isMicrophoneAllowed = AVAudioApplication.shared.recordPermission != .denied
    }

    // MARK: - Metering

    func startMetering() async -> Bool {
        guard engine == nil else { return true }
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        // Switching to Selfie mode while the permission prompt was up: the camera owns the mic now.
        guard !Task.isCancelled, engine == nil else { return engine != nil }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers])
            // Studio listens to the voice too: its haptics stay on (see `AudioRoute.allowHapticsDuringRecording`).
            AudioRoute.allowHapticsDuringRecording(true)
            // Activation waits for the audio hardware, so it must not block the main thread.
            guard try await session.activate(options: []) else { return false }
        } catch {
            return false
        }
        // Same as above, while the session was starting.
        guard !Task.isCancelled, engine == nil else { return engine != nil }
        let engine = AVAudioEngine()
        do {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return false }
            try input.installAudioTap(onBus: 0, bufferSize: 2048, format: format, tapProvider: tap.tapProvider)
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            return false
        }
        self.engine = engine
        return true
    }

    func stopMetering() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        tap.setHandler(handler)
    }

    func setLevelHandler(_ handler: (@Sendable (AudioLevelSample) -> Void)?) {
        tap.setLevelHandler(handler)
    }
}
