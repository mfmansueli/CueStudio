//
//  MicrophoneOption.swift
//  Cue Studio
//

import AVFAudio

/// An audio input the creator can record with.
nonisolated struct MicrophoneOption: Hashable, Identifiable, Sendable {
    /// The port UID.
    let id: String
    let name: String
    let detail: String
    /// The iPhone's own microphone.
    let isBuiltIn: Bool

    init(id: String, name: String, detail: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isBuiltIn = isBuiltIn
    }

    init(id: String, name: String, port: AVAudioSession.Port) {
        self.init(id: id, name: name, detail: Self.detail(for: port), isBuiltIn: port == .builtInMic)
    }

    /// The input the recording screen names: the one in use or, while the audio session hasn't
    /// reported one yet, the one picked, else the iPhone's own (what the system records with by
    /// default).
    static func inUse(current: MicrophoneOption?, preferredID: String? = nil, available: [MicrophoneOption]) -> MicrophoneOption? {
        current
            ?? available.first(where: { $0.id == preferredID })
            ?? available.first(where: \.isBuiltIn)
            ?? available.first
    }

    private static func detail(for port: AVAudioSession.Port) -> String {
        switch port {
        case .builtInMic: String(localized: "Built-in")
        case .headsetMic: String(localized: "Wired headset")
        case .bluetoothHFP, .bluetoothLE: String(localized: "Bluetooth")
        case .usbAudio: String(localized: "USB")
        case .carAudio: String(localized: "Car audio")
        default: String(localized: "External")
        }
    }
}
