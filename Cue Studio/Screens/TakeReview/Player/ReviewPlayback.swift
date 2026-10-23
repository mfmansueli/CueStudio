//
//  ReviewPlayback.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// The review's player: the take opens paused, a tap plays or pauses it, the scrubber seeks it, and the screen reads where
/// it is.
@MainActor
@Observable
final class ReviewPlayback {
    /// Playing, or about to (the audio session is getting ready).
    private(set) var isPlaying = false
    /// How much of the take has played, 0...1.
    private(set) var progress: Double = 0
    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private let audioSession: PlaybackAudioSession
    /// Readies the audio session, then plays; anything that stops playback cancels it.
    @ObservationIgnored private var startTask: Task<Void, Never>?

    init(audioSession: PlaybackAudioSession = PlaybackAudioManager()) {
        self.audioSession = audioSession
        // Never sent to an AirPlay receiver as video: that doesn't mark the scene as captured, so nothing would hide it.
        // The sound still follows the audio route.
        player.allowsExternalPlayback = false
    }

    /// Shows `item` from its start, paused.
    func load(_ item: AVPlayerItem) {
        pause()
        player.replaceCurrentItem(with: item)
        progress = 0
    }

    func play() {
        startTask?.cancel()
        isPlaying = true
        startTask = Task { [weak self, audioSession] in
            await audioSession.prepareForPlayback()
            // Paused or left while the audio session got ready.
            guard !Task.isCancelled, let self else { return }
            self.startTask = nil
            self.player.play()
        }
    }

    func pause() {
        startTask?.cancel()
        startTask = nil
        player.pause()
        isPlaying = false
    }

    /// Jumps to `fraction` of a take `duration` seconds long.
    func seek(to fraction: Double, of duration: TimeInterval) {
        progress = fraction
        player.seek(to: CMTime(seconds: duration * fraction, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Follows the player until the task is cancelled: the progress, whether it plays, and back to the start once it has played
    /// to the end.
    func follow(duration: () -> TimeInterval) async {
        while !Task.isCancelled {
            let length = duration()
            let seconds = player.currentTime().seconds
            progress = length > 0 && seconds.isFinite ? min(1, seconds / length) : 0
            isPlaying = startTask != nil || player.timeControlStatus != .paused
            if progress >= 0.999 && !isPlaying {
                await player.seek(to: .zero)
                progress = 0
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
