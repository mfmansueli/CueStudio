//
//  CueTrack.swift
//  Cue Studio
//

import Foundation

/// The music library's tracks: original music composed by Cue and played on recorded instruments from free sample libraries,
/// rendered and mastered offline (`tools/music/`, −16 LUFS, peaks under −1 dBTP) and shipped in the app as `music-<id>.m4a`. What
/// the file knows about itself (length, tempo, beats, sample libraries) comes from `music-library.json`, written by the same export
/// (`CueTrackFacts`); what the library shows of it (style, use, mood, licence) is in `CueTrack+Library`.
///
/// Adding a track: render and approve it in `tools/music/`, list it in `export_app.py` and run the export (the file and its entry
/// in the manifest), then add its case here with its title, and its style, use, mood and whether it's made for talking in
/// `CueTrack+Library` (those strings in all 20 languages). `MusicLibraryBundleTests` checks that every case has its file and entry
/// and the other way round.
nonisolated enum CueTrack: String, CaseIterable, Codable, Identifiable, Sendable {
    case morningNotes
    case lateStudy
    case brightSide
    case firstLight
    case cleanSlate
    case neonOverpass
    case tiptoeParade
    case slowTide
    case wideOpen
    case quietHours
    case goldenHour
    case cornerBooth
    case backPorch
    case nightShift
    case coldCase
    case kindWords
    case snowGlobe
    case islandHop
    case fullSend
    case stillWater

    var id: String { rawValue }

    /// The track's name, a proper name (the same in every language).
    var title: String {
        switch self {
        case .morningNotes: "Morning Notes"
        case .lateStudy: "Late Study"
        case .brightSide: "Bright Side"
        case .firstLight: "First Light"
        case .cleanSlate: "Clean Slate"
        case .neonOverpass: "Neon Overpass"
        case .tiptoeParade: "Tiptoe Parade"
        case .slowTide: "Slow Tide"
        case .wideOpen: "Wide Open"
        case .quietHours: "Quiet Hours"
        case .goldenHour: "Golden Hour"
        case .cornerBooth: "Corner Booth"
        case .backPorch: "Back Porch"
        case .nightShift: "Night Shift"
        case .coldCase: "Cold Case"
        case .kindWords: "Kind Words"
        case .snowGlobe: "Snow Globe"
        case .islandHop: "Island Hop"
        case .fullSend: "Full Send"
        case .stillWater: "Still Water"
        }
    }

    /// The file in the app's bundle (`SupportFiles/Sounds/Music/`), nil if it isn't there.
    var bundledFile: URL? {
        Bundle.main.url(forResource: "music-\(rawValue)", withExtension: "m4a")
    }

    /// Its facts from the manifest, or empty ones (no length, so it can't be added) if the manifest misses it.
    var facts: CueTrackFacts { CueTrackFacts.manifest[self] ?? CueTrackFacts(id: rawValue) }

    /// The exact length of its file.
    var duration: TimeInterval { facts.duration }

    /// Quarter notes per minute.
    var tempo: Double { facts.tempo }

    /// Every quarter note from the first downbeat to the final chord, in seconds: what Beats snaps to, known from the score.
    var beats: [TimeInterval] { facts.beats }

    /// The sample libraries its instruments come from.
    var sources: [SoundSource] { facts.sources.compactMap(SoundSource.init(rawValue:)) }
}
