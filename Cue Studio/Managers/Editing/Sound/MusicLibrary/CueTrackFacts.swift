//
//  CueTrackFacts.swift
//  Cue Studio
//

import Foundation

/// What a library track's file is, as the offline export measured and wrote it (`tools/music/export_app.py` →
/// `SupportFiles/Sounds/music-library.json`): read once, never by decoding the audio.
nonisolated struct CueTrackFacts: Decodable, Hashable, Sendable {
    /// The track's `CueTrack` raw value.
    let id: String
    /// The file's length, in seconds.
    var duration: TimeInterval = 0
    /// Quarter notes per minute.
    var tempo: Double = 0
    var beatsPerBar = 4
    /// Every quarter note from the first downbeat to the final chord, in seconds.
    var beats: [TimeInterval] = []
    /// Whether it was composed to sit under speech; absent for a track the export doesn't know that of.
    var forTalking: Bool?
    /// The `SoundSource` keys of the sample libraries it plays (kept as written, so the tests can tell an unknown one).
    var sources: [String] = []

    init(id: String) { self.id = id }

    /// The manifest's file in the bundle.
    static var manifestFile: URL? { Bundle.main.url(forResource: "music-library", withExtension: "json") }

    /// Every track the manifest lists, by track; read the first time it's asked for. A track the manifest names but the app
    /// doesn't know (a newer export) is left out.
    static let manifest: [CueTrack: CueTrackFacts] = {
        guard let url = manifestFile, let entries = try? read(url) else { return [:] }
        return Dictionary(entries.compactMap { entry in CueTrack(rawValue: entry.id).map { ($0, entry) } }) { first, _ in first }
    }()

    /// Every entry of a manifest file, in its order.
    static func read(_ url: URL) throws -> [CueTrackFacts] {
        try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url)).tracks
    }

    private struct Manifest: Decodable {
        let tracks: [CueTrackFacts]
    }
}
