//
//  AudioInputManager.swift
//  Cue Studio
//

import AVFAudio

/// Microphone choice, and the live input for Voice follow in Studio mode, where the camera (and
/// its own audio) is off: the level, and the audio itself for speech recognition.
@MainActor
@Observable
final class AudioInputManager: AudioLevelMetering {
    private(set) var inputs: [MicrophoneOption] = []

    private var engine: AVAudioEngine?
    private let tap = AudioBufferTap()

    /// Average input power in dBFS (-160...0). Nil while not metering.
    var powerLevel: Float? { engine == nil ? nil : tap.level }

    /// Lists the inputs available now (built-in, wired, Bluetooth, USB).
    func refreshInputs() {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothHFP, .defaultToSpeaker])
        }
        inputs = (session.availableInputs ?? []).map { port in
            MicrophoneOption(id: port.uid, name: port.portName, detail: Self.detail(for: port.portType))
        }
    }

    /// Makes `id` the preferred input; nil returns to the system default.
    func select(_ id: String?) {
        let session = AVAudioSession.sharedInstance()
        let port = session.availableInputs?.first { $0.uid == id }
        try? session.setPreferredInput(port)
    }

    // MARK: - Metering

    func startMetering() async -> Bool {
        guard engine == nil else { return true }
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        // Switching to Selfie mode while the permission prompt was up: the camera owns the mic now.
        guard !Task.isCancelled, engine == nil else { return engine != nil }
        let session = AVAudioSession.sharedInstance()
        let engine = AVAudioEngine()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return false }
            input.installTap(onBus: 0, bufferSize: 2048, format: format, block: tap.tapBlock)
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
        tap.resetLevel()
    }

    func setAudioHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        tap.setHandler(handler)
    }

    private static func detail(for type: AVAudioSession.Port) -> String {
        switch type {
        case .builtInMic: String(localized: "Built-in")
        case .headsetMic: String(localized: "Wired headset")
        case .bluetoothHFP, .bluetoothLE: String(localized: "Bluetooth")
        case .usbAudio: String(localized: "USB")
        case .carAudio: String(localized: "Car audio")
        default: String(localized: "External")
        }
    }
}
