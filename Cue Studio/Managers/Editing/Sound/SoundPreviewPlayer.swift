//
//  SoundPreviewPlayer.swift
//  Cue Studio
//

import AVFoundation
import Observation

/// Hears a sound: a sound effect from its file (`SoundEffectFiles`), or any sound file. A new one stops the last; `playingKey` goes back
/// to nil when it ends. Like the editor's player, it makes the playback session ready off the main thread first
/// (`PlaybackAudioSession`) and plays with AVPlayer: AVAudioPlayer activates the session on the main thread on every play, and the
/// default session is silent under the Ring/Silent switch.
@MainActor
@Observable
final class SoundPreviewPlayer: SoundPreviewing {
    private(set) var playingKey: String?
    @ObservationIgnored private let audioSession: PlaybackAudioSession
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var playing: Task<Void, Never>?

    init(audioSession: PlaybackAudioSession = PlaybackAudioManager()) {
        self.audioSession = audioSession
    }

    func play(_ effect: SoundEffect) {
        guard let url = try? SoundEffectFiles.file(for: effect) else { return }
        play(url, key: effect.rawValue)
    }

    func play(_ url: URL, key: String) {
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        playingKey = key
        playing = Task { [weak self, audioSession] in
            let length = try? await item.asset.load(.duration)
            await audioSession.prepareForPlayback()
            guard !Task.isCancelled, let self, self.player === player else { return }
            guard let length, length.seconds > 0 else {
                self.stop()
                return
            }
            player.play()
            try? await Task.sleep(for: .seconds(length.seconds + 0.05))
            guard !Task.isCancelled else { return }
            self.stop()
        }
    }

    func stop() {
        playing?.cancel()
        playing = nil
        player?.pause()
        player = nil
        playingKey = nil
    }
}
