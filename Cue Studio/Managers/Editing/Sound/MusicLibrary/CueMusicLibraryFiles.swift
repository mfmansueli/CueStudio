//
//  CueMusicLibraryFiles.swift
//  Cue Studio
//

import Foundation

/// The library's files as they ship, in the app's bundle (`music-<id>.m4a`).
nonisolated struct CueMusicLibraryFiles: MusicLibraryFiles {
    /// A track the bundle doesn't have (an install missing a resource).
    struct MissingFile: Error {
        let track: CueTrack
    }

    func file(for track: CueTrack) async throws -> URL {
        try Task.checkCancellation()
        guard let url = track.bundledFile else { throw MissingFile(track: track) }
        return url
    }
}
