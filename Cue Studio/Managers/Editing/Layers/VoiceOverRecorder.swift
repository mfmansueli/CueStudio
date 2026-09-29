//
//  VoiceOverRecorder.swift
//  Cue Studio
//

import AVFAudio
import Foundation

/// Records a voice-over with `AVAudioRecorder` into `EditMediaFiles` (AAC, mono). The file never
/// leaves the device. Bluetooth and wired mics work like they do for takes.
@MainActor
@Observable
final class VoiceOverRecorder: VoiceOverRecording {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var fileName: String?
    @ObservationIgnored private var clock: Task<Void, Never>?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() async throws {
        guard !isRecording else { return }
        // Setting up the session blocks, so never on the main thread.
        try await Task.detached {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try session.setActive(true)
        }.value
        let file = try EditMediaFiles.newFile(pathExtension: "m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: file.url, settings: settings)
        guard recorder.record() else { throw VoiceOverError.couldNotRecord }
        self.recorder = recorder
        fileName = file.name
        elapsed = 0
        isRecording = true
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime
            }
        }
    }

    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard let recorder, let fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        finish()
        return (fileName, duration)
    }

    func cancel() {
        guard let recorder else { return }
        recorder.stop()
        _ = recorder.deleteRecording()
        finish()
    }

    private func finish() {
        clock?.cancel()
        clock = nil
        recorder = nil
        fileName = nil
        isRecording = false
    }
}
