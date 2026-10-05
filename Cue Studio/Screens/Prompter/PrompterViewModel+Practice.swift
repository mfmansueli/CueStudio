//
//  PrompterViewModel+Practice.swift
//  Cue Studio
//

import AVFAudio

/// The first flight's practice run: the real prompter over the camera, not recording.
extension PrompterViewModel {
    /// The practice starts on its own, in the mode the creator uses (the text follows the voice from the first word, or flows at
    /// the set speed). Without the microphone Voice Following can't listen, so the practice flows at a steady pace.
    func startPractice() {
        guard isPractice, !isPlaying else { return }
        if AVAudioApplication.shared.recordPermission == .denied { setScrollMode(.steady) }
        play()
    }
}
