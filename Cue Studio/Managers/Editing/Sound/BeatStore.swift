//
//  BeatStore.swift
//  Cue Studio
//

import Foundation

/// Where a sound file's beats are kept: next to its copy in the edit's media (`<file>.cuebeats`), so they're found once and go
/// with the file. A cache: when it's missing, the beats are found again.
nonisolated enum BeatStore {
    static let pathExtension = "cuebeats"

    private struct Stored: Codable {
        var version = 1
        var tempo: Double
        var beats: [TimeInterval]
    }

    static func url(forSound fileName: String) -> URL {
        EditMediaFiles.url(for: fileName).appendingPathExtension(pathExtension)
    }

    /// The beats kept for the file; nil when they were never found (an empty list: the file has no pulse).
    static func load(forSound fileName: String) -> BeatTracker.Result? {
        guard let data = try? Data(contentsOf: url(forSound: fileName)),
              let stored = try? JSONDecoder().decode(Stored.self, from: data), stored.version == 1 else { return nil }
        return BeatTracker.Result(beats: stored.beats, tempo: stored.tempo)
    }

    /// Keeps the beats next to the file; nothing when the file is gone (removed while its beats were being found).
    static func save(_ result: BeatTracker.Result, forSound fileName: String) {
        guard FileManager.default.fileExists(atPath: EditMediaFiles.url(for: fileName).path(percentEncoded: false)) else { return }
        var file = url(forSound: fileName)
        guard let data = try? JSONEncoder().encode(Stored(tempo: result.tempo, beats: result.beats.map { ($0 * 1000).rounded() / 1000 })) else { return }
        try? data.write(to: file, options: .atomic)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? file.setResourceValues(values)
    }
}
