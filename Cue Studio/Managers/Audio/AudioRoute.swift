//
//  AudioRoute.swift
//  Cue Studio
//

import AVFAudio

/// The app's audio session as recording sees it: the inputs connected, the one in use and the one
/// the creator picked. The camera and the Audio Input picker both go through here, so the mic named
/// on the recording screen is the one that ends up in the take.
nonisolated enum AudioRoute {
    /// Records video with sound. Bluetooth HFP lets AirPods and Bluetooth mics show up as inputs.
    static func configureForCapture() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothHFP, .defaultToSpeaker])
        // The capture session activates it too; doing it here makes the route (and the inputs
        // list) current before the first frame. Blocks, so never on the main thread.
        try? session.setActive(true)
    }

    /// Without a recording category the system lists no inputs.
    static func prepareToListInputs() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playAndRecord else { return }
        try? session.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothHFP, .defaultToSpeaker])
    }

    /// Built-in, wired, Bluetooth and USB inputs connected now.
    static func availableInputs() -> [MicrophoneOption] {
        (AVAudioSession.sharedInstance().availableInputs ?? []).map(option(for:))
    }

    /// The input the audio comes from right now. Nil while the session isn't set up to record.
    static func currentInput() -> MicrophoneOption? {
        AVAudioSession.sharedInstance().currentRoute.inputs.first.map(option(for:))
    }

    /// The input picked with `prefer(inputID:)`, while it's connected.
    static func preferredInputID() -> String? {
        AVAudioSession.sharedInstance().preferredInput?.uid
    }

    /// Makes `id` the input to record from. Nil, or an input that is no longer connected, hands the
    /// choice back to the system (the mic plugged in last, or the iPhone's).
    static func prefer(inputID id: String?) {
        let session = AVAudioSession.sharedInstance()
        let port = id.flatMap { id in session.availableInputs?.first { $0.uid == id } }
        guard session.preferredInput?.uid != port?.uid else { return }
        try? session.setPreferredInput(port)
    }

    private static func option(for port: AVAudioSessionPortDescription) -> MicrophoneOption {
        MicrophoneOption(id: port.uid, name: port.portName, port: port.portType)
    }
}
