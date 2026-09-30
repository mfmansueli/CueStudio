//
//  PlaybackAudioManager.swift
//  Cue Studio
//

import AVFAudio
import Observation
import OSLog

/// Playback is intentional media audio: it must not inherit the default session, which the
/// Ring/Silent switch silences. Capture configures its own recording category on every start.
@MainActor
@Observable
final class PlaybackAudioManager: PlaybackAudioSession {
    private let logger = Logger(subsystem: "studio.cue", category: "PlaybackAudio")

    func prepareForPlayback() async {
        guard !Task.isCancelled else { return }
        do {
            // Both changing an active route and activation can wait for the hardware.
            let preparation = Task.detached {
                try Task.checkCancellation()
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback)
                try Task.checkCancellation()
                return try await session.activate(options: [])
            }
            let activated = try await withTaskCancellationHandler {
                try await preparation.value
            } onCancel: {
                preparation.cancel()
            }
            if !activated { logger.error("The playback audio session could not be activated") }
        } catch is CancellationError {
            return
        } catch {
            // A temporary route failure must not make the recorded video inaccessible.
            logger.error("Could not prepare playback audio: \(error.localizedDescription, privacy: .public)")
        }
    }
}
