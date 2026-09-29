//
//  FakeMicrophones.swift
//  Cue StudioTests
//

@testable import Cue_Studio

@MainActor
final class FakeMicrophones: MicrophoneListing {
    static let iPhone = MicrophoneOption(id: "built-in", name: "iPhone Microphone", detail: "Built-in", isBuiltIn: true)
    static let airPods = MicrophoneOption(id: "airpods-pro", name: "AirPods Pro", detail: "Bluetooth")

    var inputs: [MicrophoneOption] = [FakeMicrophones.iPhone]
    /// Nil falls back to the built-in mic, like the system does.
    var current: MicrophoneOption?
    private(set) var refreshCount = 0

    var inputInUse: MicrophoneOption? {
        MicrophoneOption.inUse(current: current, available: inputs)
    }

    func refreshInputs() {
        refreshCount += 1
    }
}
