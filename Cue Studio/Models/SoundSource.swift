//
//  SoundSource.swift
//  Cue Studio
//

import Foundation

/// A free sample library whose recordings play Cue's music and sound effects (the instruments are recorded; the notes, the mix and
/// the master are Cue's, made offline in `tools/music/`). The raw values are the keys `music-library.json` names a track's sources
/// by. Every one is CC0 (owner's decision, 29/10: nothing that asks for credit), so no track or effect asks a video for credit;
/// Settings › Acknowledgements credits them anyway, with the licence's text. A library whose licence asks for credit would add a
/// `Licence` case that says so, and the tracks that play it would name it in their ⓘ (`MusicTrackLicence`).
nonisolated enum SoundSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case vsco2
    case vcsl
    case virtuosityDrums
    case swirlyDrums
    case freepatsGuitar
    case kenney

    /// The licences the libraries come under, each with its legal text in the bundle.
    enum Licence: Sendable {
        /// CC0 1.0: dedicated to the public domain, nothing asked in return.
        case cc0

        /// Its short name, the same in every language.
        var name: String {
            switch self {
            case .cc0: "CC0 1.0"
            }
        }

        /// Whether a video that uses the sound must credit the library.
        var requiresCredit: Bool {
            switch self {
            case .cc0: false
            }
        }

        /// The legal code's file in the bundle (`SupportFiles/Licenses/`, without ".txt").
        var file: String {
            switch self {
            case .cc0: "CC0-1.0"
            }
        }
    }

    var id: String { rawValue }

    /// The library's name, a proper name (the same in every language).
    var library: String {
        switch self {
        case .vsco2: "VSCO 2 Community Edition"
        case .vcsl: "Versilian Community Sample Library (VCSL)"
        case .virtuosityDrums: "Virtuosity Drums"
        case .swirlyDrums: "Swirly Drums"
        case .freepatsGuitar: "Spanish Classical Guitar"
        case .kenney: "Kenney sound packs (Interface, UI, RPG, Casino)"
        }
    }

    /// Who recorded it.
    var author: String {
        switch self {
        case .vsco2, .vcsl: "Versilian Studios"
        case .virtuosityDrums: "Versilian Studios and Karoryfer Samples, played by Austin McMahon"
        case .swirlyDrums: "Karoryfer Samples"
        case .freepatsGuitar: "FreePats project"
        case .kenney: "Kenney"
        }
    }

    var licence: Licence { .cc0 }

    var requiresCredit: Bool { licence.requiresCredit }

    /// Where it's published.
    var url: URL {
        let address = switch self {
        case .vsco2: "https://github.com/sgossner/VSCO-2-CE"
        case .vcsl: "https://github.com/sgossner/VCSL"
        case .virtuosityDrums: "https://github.com/sfzinstruments/virtuosity_drums"
        case .swirlyDrums: "https://github.com/sfzinstruments/karoryfer.swirly-drums"
        case .freepatsGuitar: "https://freepats.zenvoid.org"
        case .kenney: "https://kenney.nl"
        }
        return URL(string: address) ?? URL(filePath: "/")
    }

    /// What its recordings are, in a few words (Settings › Acknowledgements).
    var instruments: String {
        switch self {
        case .vsco2: String(localized: "Orchestral instruments and percussion")
        case .vcsl: String(localized: "Pianos, percussion, whistles and small instruments")
        case .virtuosityDrums: String(localized: "Drum kit")
        case .swirlyDrums: String(localized: "Drum kit played with brushes")
        case .freepatsGuitar: String(localized: "Nylon-string guitar")
        case .kenney: String(localized: "Clicks, pages, coins and footsteps")
        }
    }

    /// The credit a video gives it when its licence asks for one: "<library> by <author> (<licence>)".
    var credit: String {
        String(localized: "\(library) by \(author) (\(licence.name))", comment: "Music library: the credit a sample library asks for")
    }

    /// The licence's legal text, as shipped.
    var licenceText: String {
        Bundle.main.url(forResource: licence.file, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }
}
