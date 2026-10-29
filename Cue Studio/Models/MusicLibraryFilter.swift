//
//  MusicLibraryFilter.swift
//  Cue Studio
//

import Foundation

/// What the music library shows: every track, the ones made to sit under talking, or one mood.
nonisolated enum MusicLibraryFilter: Hashable, Identifiable, Sendable {
    case all
    case underTalking
    case mood(MusicMood)

    /// Every filter, in the order the chips show.
    static let allCases: [MusicLibraryFilter] = [.all, .underTalking] + MusicMood.allCases.map { .mood($0) }

    var id: String {
        switch self {
        case .all: "all"
        case .underTalking: "underTalking"
        case .mood(let mood): mood.rawValue
        }
    }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .underTalking: String(localized: "For talking")
        case .mood(let mood): mood.label
        }
    }

    func includes(_ track: CueTrack) -> Bool {
        switch self {
        case .all: true
        case .underTalking: track.isForTalking
        case .mood(let mood): track.mood == mood
        }
    }
}
