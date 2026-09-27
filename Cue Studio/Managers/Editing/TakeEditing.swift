//
//  TakeEditing.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// The media work behind Quick edit. Screens depend on this protocol so tests can use a fake.
protocol TakeEditing: AnyObject {
    /// Pauses long enough to cut.
    func silences(inVideoAt url: URL) async throws -> [TimeSpan]
    /// Captions from the script, timed to the voice; spread evenly when no speech model can listen.
    func captions(forVideoAt url: URL, script: String, duration: TimeInterval) async -> [CaptionCue]
    /// The edited take for the preview player.
    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem
}
