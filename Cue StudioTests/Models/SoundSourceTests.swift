//
//  SoundSourceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The sample libraries behind the music and the effects: each ships its licence's legal text, all are CC0 (owner's decision: no
/// track or effect asks for credit), and a licence lists a track's libraries in the libraries' order.
@Suite("Sound sources")
struct SoundSourceTests {
    @Test func everySourceShipsItsLicence() {
        for source in SoundSource.allCases {
            #expect(!source.library.isEmpty && !source.author.isEmpty && !source.instruments.isEmpty, "\(source)")
            #expect(source.url.scheme == "https", "\(source)")
            switch source.licence {
            case .cc0:
                #expect(source.licenceText.contains("CC0 1.0 Universal"), "\(source)")
                #expect(!source.requiresCredit, "\(source)")
            }
        }
    }

    @Test func aTrackOnCC0LibrariesNeedsNoCredit() {
        let licence = MusicTrackLicence(sources: [.freepatsGuitar, .vcsl, .vsco2])
        #expect(licence.attribution == String(localized: "No credit needed."))
        #expect(licence.sources == [.vsco2, .vcsl, .freepatsGuitar], "in the libraries' order, whatever order they were given in")
        #expect(licence.libraries?.contains(SoundSource.vsco2.library) == true)
        #expect(MusicTrackLicence(sources: []).libraries == nil)
    }

    /// Settings › Acknowledgements lists every library the music and the effects use, and no other.
    @Test func theAcknowledgementsListWhatShips() {
        let used = SoundSource.inUse
        for track in CueTrack.allCases {
            #expect(track.sources.allSatisfy(used.contains), "\(track)")
        }
        #expect(SoundSource.soundEffectSources.allSatisfy(used.contains))
        let needed = Set(CueTrack.allCases.flatMap(\.sources) + SoundSource.soundEffectSources)
        #expect(Set(used) == needed)
        #expect(SoundSource.soundEffectSources.allSatisfy { !$0.requiresCredit }, "effects need no credit")
    }
}
