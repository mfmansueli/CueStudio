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
    /// Frames per second of the recording, read from the file; nil when it can't be read.
    func frameRate(ofVideoAt url: URL) async -> Double?
    /// Clean Up's findings: pauses from the take's loudness, and filler words and possible retakes
    /// from its transcript in `language` (pauses only when no speech model can listen). None for a
    /// take without sound. Throws when the sound can't be read.
    func cleanUpSuggestions(forVideoAt url: URL, language: SpeechLanguageRequest) async throws -> [CleanUpSuggestion]
    /// Captions from what is said in the take, heard in `language`. The voice decides the words and
    /// when; `script` (empty for a take without one) only lends its spelling where it reliably
    /// matches. Nothing is ever spread over the take: without sound, speech or a model for the
    /// language, the outcome says so. Reports where it is through `progress`; throws
    /// `CancellationError` when the task is cancelled, and other errors when the sound can't be
    /// read.
    func captions(
        forVideoAt url: URL, script: String, language: SpeechLanguageRequest,
        progress: @escaping @Sendable (CaptionProgress) -> Void
    ) async throws -> CaptionOutcome
    /// The edited take for a player.
    func previewItem(forVideoAt url: URL, edit: TakeEdit) async throws -> AVPlayerItem
    /// The cover drawn as a JPEG (a frame or photo, cropped to the take's frame, with its title);
    /// nil when its picture can't be read.
    func coverImage(_ cover: VideoCover, forVideoAt url: URL, edit: TakeEdit) async -> Data?
}
