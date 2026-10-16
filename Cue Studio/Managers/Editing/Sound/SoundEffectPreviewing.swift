//
//  SoundEffectPreviewing.swift
//  Cue Studio
//

import Foundation

/// Plays a sound effect once, to hear it before adding it. Behind a protocol so the editor is tested without sound.
@MainActor
protocol SoundEffectPreviewing: AnyObject {
    func play(_ effect: SoundEffect)
    func stop()
}
