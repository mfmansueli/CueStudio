//
//  VoiceOverRecorderDelegate.swift
//  Cue Studio
//

import AVFAudio
import Foundation

/// `AVAudioRecorder`'s delegate for `VoiceOverRecorder`: an encode error, or a recording that ended unsuccessfully, is handed
/// on, on the main actor.
final class VoiceOverRecorderDelegate: NSObject, AVAudioRecorderDelegate {
    private let failed: @MainActor () -> Void

    init(failed: @escaping @MainActor () -> Void) {
        self.failed = failed
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        Task { @MainActor [failed] in failed() }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        Task { @MainActor [failed] in failed() }
    }
}
