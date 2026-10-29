//
//  CueTrack+Library.swift
//  Cue Studio
//

import Foundation

/// What the music library shows of each of Cue's tracks: its style and mood, what it suits, whether it was made to sit under
/// talking (sparse in the voice's range, steady, without a busy melody), and its licence.
nonisolated extension CueTrack {
    /// The kind of music, in a few words.
    var style: String {
        switch self {
        case .morningNotes: String(localized: "Acoustic guitar")
        case .lateStudy: String(localized: "Lo-fi hip-hop")
        case .brightSide: String(localized: "Acoustic pop")
        case .firstLight: String(localized: "Cinematic build")
        case .cleanSlate: String(localized: "Minimal marimba")
        case .neonOverpass: String(localized: "Nu-disco")
        case .tiptoeParade: String(localized: "Marimba and woodwinds")
        case .slowTide: String(localized: "Ambient")
        case .wideOpen: String(localized: "Uplifting piano and strings")
        case .quietHours: String(localized: "Solo piano")
        case .goldenHour: String(localized: "Bossa nova")
        case .cornerBooth: String(localized: "Jazz trio")
        case .backPorch: String(localized: "Folk-pop")
        case .nightShift: String(localized: "Chill hip-hop")
        case .coldCase: String(localized: "music.style.suspense", defaultValue: "Suspense")
        case .kindWords: String(localized: "Tender waltz")
        case .snowGlobe: String(localized: "Holiday swing")
        case .islandHop: String(localized: "Tropical")
        case .fullSend: String(localized: "Orchestral rock")
        case .stillWater: String(localized: "Meditation")
        }
    }

    /// What it suits.
    var use: String {
        switch self {
        case .morningNotes: String(localized: "Vlogs, everyday talk")
        case .lateStudy: String(localized: "Study, explainers")
        case .brightSide: String(localized: "Intros, vlogs")
        case .firstLight: String(localized: "Reveals, trailers")
        case .cleanSlate: String(localized: "Tutorials, tech")
        case .neonOverpass: String(localized: "Night, fashion, retro")
        case .tiptoeParade: String(localized: "Comedy, sketches")
        case .slowTide: String(localized: "Stories, calm moments")
        case .wideOpen: String(localized: "Advice, business, lessons")
        case .quietHours: String(localized: "Reflections, soft talk")
        case .goldenHour: String(localized: "Food, travel, lifestyle")
        case .cornerBooth: String(localized: "Food, cafés, interviews")
        case .backPorch: String(localized: "DIY, travel, family")
        case .nightShift: String(localized: "Gaming, commentary, reviews")
        case .coldCase: String(localized: "True crime, mysteries")
        case .kindWords: String(localized: "Weddings, family, thank-yous")
        case .snowGlobe: String(localized: "Holidays, gifts, recipes")
        case .islandHop: String(localized: "Travel, summer, food")
        case .fullSend: String(localized: "Sports, fitness, challenges")
        case .stillWater: String(localized: "Wellness, skincare, yoga")
        }
    }

    var mood: MusicMood {
        switch self {
        case .morningNotes, .quietHours, .slowTide, .kindWords, .stillWater: .calm
        case .lateStudy, .goldenHour, .cornerBooth, .nightShift: .chill
        case .cleanSlate: .focus
        case .brightSide, .neonOverpass, .wideOpen, .backPorch, .islandHop, .fullSend: .upbeat
        case .tiptoeParade, .snowGlobe: .playful
        case .firstLight, .coldCase: .cinematic
        }
    }

    /// Made to sit under a voice: little in 1–4 kHz, steady, no lead melody (the manifest's `forTalking`, where the export says).
    var isForTalking: Bool {
        switch self {
        case .morningNotes, .lateStudy, .cleanSlate, .slowTide, .wideOpen, .quietHours, .goldenHour, .cornerBooth, .backPorch,
             .nightShift, .coldCase, .kindWords, .snowGlobe, .islandHop, .stillWater: true
        case .brightSide, .firstLight, .neonOverpass, .tiptoeParade, .fullSend: false
        }
    }

    /// Its origin, terms and credit, from the sample libraries it plays.
    var licence: MusicTrackLicence { MusicTrackLicence(sources: sources) }

    /// Whether `query` is in its name, style, use or mood (ignoring case and accents, in the creator's language).
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let text = [title, style, use, mood.label].joined(separator: " ")
        return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
