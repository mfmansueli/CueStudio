//
//  SoundPreviewing.swift
//  Cue Studio
//

import Foundation

/// Plays a sound once, to hear it before adding it: a sound effect, a track of Cue's library, a spoken narration's first
/// sentence. One at a time; `playingKey` says which, so its button shows Stop. Behind a protocol so the editor is tested without
/// sound.
@MainActor
protocol SoundPreviewing: AnyObject {
    /// What's playing: an effect's raw value, or the key it was played with; nil once it ends or stops.
    var playingKey: String? { get }
    func play(_ effect: SoundEffect)
    func play(_ url: URL, key: String)
    func stop()
}
