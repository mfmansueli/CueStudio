//
//  TakeEditing.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// The media work behind Quick edit. Screens depend on this protocol so tests can use a fake.
protocol TakeEditing: AnyObject {
    /// Length of the recording, read from the file. Throws `EditSourceError` when the file is gone
    /// or can't be played.
    func sourceDuration(ofVideoAt url: URL) async throws -> TimeInterval
    /// Pauses long enough to cut.
    func silences(inVideoAt url: URL) async throws -> [TimeSpan]
    /// Captions from the script, timed to the voice; spread evenly when no speech model can listen.
    func captions(forVideoAt url: URL, script: String, duration: TimeInterval) async -> [CaptionCue]
    /// The edited take for a player.
    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem
}
