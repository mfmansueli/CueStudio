//
//  SoundEffectPreviewPlayer.swift
//  Cue Studio
//

import AVFoundation

/// Hears a sound effect with AVAudioPlayer, from the file Cue made for it.
@MainActor
final class SoundEffectPreviewPlayer: SoundEffectPreviewing {
    private var player: AVAudioPlayer?

    func play(_ effect: SoundEffect) {
        guard let url = try? SoundEffectSynth.file(for: effect) else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
