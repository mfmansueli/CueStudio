//
//  FakeSoundPreviews.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Previews without sound: remembers what "plays" until it's stopped.
final class FakeSoundPreviews: SoundPreviewing {
    private(set) var playingKey: String?
    private(set) var played: [URL] = []

    func play(_ effect: SoundEffect) { playingKey = effect.rawValue }

    func play(_ url: URL, key: String) {
        played.append(url)
        playingKey = key
    }

    func stop() { playingKey = nil }
}
