//
//  MusicLibraryFiles.swift
//  Cue Studio
//

import Foundation

/// The library's tracks as sound files. Behind a protocol so the editor is tested with files of its own (a second of silence,
/// a delay, a failure) instead of the bundle's.
protocol MusicLibraryFiles: Sendable {
    /// The track's file. Throws `CancellationError` when the task is cancelled.
    func file(for track: CueTrack) async throws -> URL
}
