//
//  MusicLibraryBundleTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The music library as it ships: every `CueTrack` has its file in the bundle and its entry in `music-library.json`, and nothing
/// is there without a track; each file is what its entry says (length, 48 kHz stereo), its beats are the score's quarter notes,
/// its sample libraries are known ones (all CC0), and its licence asks for credit exactly when one of them does (none today).
@Suite("Music library bundle")
struct MusicLibraryBundleTests {
    private func manifest() throws -> [CueTrackFacts] {
        try CueTrackFacts.read(try #require(CueTrackFacts.manifestFile))
    }

    @Test func everyTrackHasItsFileAndEntryAndNothingElseShips() throws {
        let entries = try manifest()
        #expect(Set(entries.map(\.id)) == Set(CueTrack.allCases.map(\.rawValue)))
        #expect(entries.count == CueTrack.allCases.count, "an entry is listed twice")
        let folder = try #require(Bundle.main.resourceURL)
        let shipped = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasPrefix("music-") && $0.hasSuffix(".m4a") }
        #expect(Set(shipped) == Set(CueTrack.allCases.map { "music-\($0.rawValue).m4a" }))
        for track in CueTrack.allCases {
            #expect(track.bundledFile != nil, "\(track)")
            #expect(CueTrackFacts.manifest[track] != nil, "\(track)")
        }
        #expect(Set(CueTrack.allCases.map(\.title)).count == CueTrack.allCases.count, "every title is its own")
    }

    @Test(arguments: CueTrack.allCases)
    func theFileIsWhatTheManifestSays(_ track: CueTrack) throws {
        let file = try AVAudioFile(forReading: try #require(track.bundledFile))
        #expect(file.fileFormat.sampleRate == 48_000)
        #expect(file.fileFormat.channelCount == 2)
        let decoded = Double(file.length) / file.processingFormat.sampleRate
        #expect(abs(decoded - track.duration) < 0.02, "\(track): \(decoded) s, manifest \(track.duration) s")
        #expect((45...150).contains(track.duration), "\(track): \(track.duration) s")
    }

    @Test(arguments: CueTrack.allCases)
    func theBeatsAreItsQuarterNotes(_ track: CueTrack) {
        let beats = track.beats
        #expect(beats.count > 16, "\(track)")
        #expect((beats.first ?? -1) >= 0 && (beats.first ?? 1) < 0.2, "\(track) starts on its first beat")
        #expect((beats.last ?? .infinity) < track.duration, "\(track)")
        #expect(track.tempo > 40 && track.tempo < 200, "\(track): \(track.tempo) BPM")
        let spacing = 60 / track.tempo
        for (earlier, later) in zip(beats, beats.dropFirst()) {
            #expect(later > earlier, "\(track)")
            // The manifest keeps a tenth of a millisecond.
            #expect(abs((later - earlier) - spacing) < 0.0002, "\(track): \(later - earlier) s, not \(spacing) s")
        }
    }

    @Test func forTalkingAndSourcesAgreeWithTheManifest() throws {
        for entry in try manifest() {
            let track = try #require(CueTrack(rawValue: entry.id))
            if let forTalking = entry.forTalking {
                #expect(track.isForTalking == forTalking, "\(track)")
            }
            let unknown = entry.sources.filter { SoundSource(rawValue: $0) == nil }
            #expect(unknown.isEmpty, "\(track): \(unknown)")
            #expect(track.sources.map(\.rawValue).sorted() == entry.sources.sorted(), "\(track)")
        }
    }

    @Test func aTrackAsksForCreditOnlyWhenOneOfItsSourcesDoes() {
        for track in CueTrack.allCases {
            let licence = track.licence
            #expect(!licence.origin.isEmpty && !licence.terms.isEmpty, "\(track)")
            let credited = track.sources.filter(\.requiresCredit)
            if credited.isEmpty {
                #expect(licence.attribution == String(localized: "No credit needed."), "\(track)")
            } else {
                for source in credited {
                    #expect(licence.attribution.contains(source.author) && licence.attribution.contains(source.library), "\(track)")
                }
            }
            #expect(licence.sources == SoundSource.allCases.filter(track.sources.contains), "\(track)")
            #expect((licence.libraries == nil) == track.sources.isEmpty, "\(track)")
        }
    }
}
