//
//  MusicTrackLicence.swift
//  Cue Studio
//

import Foundation

/// Where a library track comes from and what the creator may do with it, as the library's ⓘ shows it. Cue composes every track
/// (`CueTrack`) and plays it on recorded instruments from free sample libraries (`SoundSource`), so the terms are Cue's and the
/// credit, if any, is what those libraries' licences ask: none when all of a track's sources are CC0 (every one today), the author
/// and library of each one that asks for it otherwise.
nonisolated struct MusicTrackLicence: Hashable, Sendable {
    /// Who made it and how.
    let origin: String
    /// What the creator may do with it.
    let terms: String
    /// The credit the video must give, or that none is needed.
    let attribution: String
    /// The sample libraries its instruments come from, in the library's order.
    let sources: [SoundSource]

    /// The licence of a track played on `sources`.
    init(sources: [SoundSource]) {
        let ordered = SoundSource.allCases.filter(sources.contains)
        self.sources = ordered
        origin = String(localized: "Composed by Cue and played on recorded instruments from free sample libraries (credited in Settings › Acknowledgements).")
        terms = String(localized: "Free to use in the videos you make, monetized ones included.")
        let credits = ordered.filter(\.requiresCredit).map(\.credit)
        attribution = credits.isEmpty
            ? String(localized: "No credit needed.")
            : String(localized: "Credit in your video: \(credits.formatted(.list(type: .and)))")
    }

    /// "Sample libraries: VSCO 2 Community Edition and Swirly Drums", or nil for a track that names none.
    var libraries: String? {
        guard !sources.isEmpty else { return nil }
        return String(localized: "Sample libraries: \(sources.map(\.library).formatted(.list(type: .and)))")
    }
}
