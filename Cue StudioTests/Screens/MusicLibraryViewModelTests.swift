//
//  MusicLibraryViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The music library (`MusicLibraryViewModel`, `CueTrack+Library`): search and filters, hearing a track (fetched first,
/// stopped by a second tap or by another track, a failure said on the row), what it covers of the video, and adding one.
@MainActor
@Suite("Music library")
struct MusicLibraryViewModelTests {
    private func library(
        files: FakeMusicLibraryFiles = FakeMusicLibraryFiles(), previews: FakeSoundPreviews = FakeSoundPreviews(),
        editDuration: TimeInterval = 60, add: @escaping (CueTrack) async -> Bool = { _ in true }
    ) -> MusicLibraryViewModel {
        MusicLibraryViewModel(files: files, previews: previews, editDuration: editDuration, add: add)
    }

    @Test func everyTrackHasALicenceAStyleAndAUse() {
        for track in CueTrack.allCases {
            #expect(!track.style.isEmpty && !track.use.isEmpty)
            #expect(!track.licence.origin.isEmpty && !track.licence.terms.isEmpty && !track.licence.attribution.isEmpty)
        }
        // At least four tracks are made to sit under talking, and every mood has one.
        #expect(CueTrack.allCases.filter(\.isForTalking).count >= 4)
        #expect(Set(CueTrack.allCases.map(\.mood)) == Set(MusicMood.allCases))
    }

    @Test func searchFindsByNameStyleOrUseIgnoringCaseAndAccents() {
        let library = library()
        library.query = "lo-fi"
        #expect(library.tracks == [.lateStudy])
        library.query = "TUTORIALS"
        #expect(library.tracks == [.cleanSlate])
        library.query = "piano solo"
        #expect(library.tracks == [.quietHours])
        library.query = "nothing like this"
        #expect(library.tracks.isEmpty)
        library.query = "   "
        #expect(library.tracks == CueTrack.allCases)
    }

    @Test func filtersKeepTalkingOrOneMood() {
        let library = library()
        library.filter = .underTalking
        #expect(!library.tracks.isEmpty && library.tracks.allSatisfy(\.isForTalking))
        library.filter = .mood(.playful)
        #expect(library.tracks == [.tiptoeParade, .snowGlobe])
        // The search narrows the filter.
        library.filter = .mood(.calm)
        library.query = "piano"
        #expect(library.tracks == [.quietHours])
    }

    @Test func aTrackIsHeardAndASecondTapStopsIt() async throws {
        let files = FakeMusicLibraryFiles(), previews = FakeSoundPreviews()
        defer { files.removeAll() }
        let library = library(files: files, previews: previews)
        library.togglePreview(.morningNotes)
        #expect(library.preparing == .morningNotes)
        try await waitUntil { library.isPlaying(.morningNotes) }
        #expect(library.preparing == nil)
        #expect(previews.played.last?.lastPathComponent == "morningNotes.caf")
        library.togglePreview(.morningNotes)
        #expect(!library.isPlaying(.morningNotes) && previews.playingKey == nil)
    }

    @Test func anotherTrackStopsTheOneBeingMade() async throws {
        let files = FakeMusicLibraryFiles(delay: .seconds(5)), previews = FakeSoundPreviews()
        defer { files.removeAll() }
        let library = library(files: files, previews: previews)
        library.togglePreview(.slowTide)
        library.togglePreview(.brightSide)
        #expect(library.preparing == .brightSide)
        library.stop()
        #expect(library.preparing == nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(previews.played.isEmpty)
    }

    @Test func aTrackThatCantBeMadeSaysSo() async throws {
        let library = library(files: FakeMusicLibraryFiles(failure: CocoaError(.fileWriteOutOfSpace)))
        library.togglePreview(.wideOpen)
        try await waitUntil { library.failed == .wideOpen }
        #expect(library.preparing == nil)
        // Trying again clears it.
        library.togglePreview(.wideOpen)
        #expect(library.failed == nil)
    }

    @Test func coverageSaysWhatOfTheVideoTheTrackCovers() {
        let short = library(editDuration: 30)
        #expect(short.coverage(of: .morningNotes) == String(localized: "Covers the whole video"))
        let long = library(editDuration: 600)
        #expect(long.coverage(of: .morningNotes).contains(DurationText.clock(CueTrack.morningNotes.duration)))
    }

    @Test func addingStopsThePreviewAndSaysWhetherItWentIn() async throws {
        let previews = FakeSoundPreviews()
        var added: [CueTrack] = []
        let library = library(previews: previews) { track in
            added.append(track)
            return true
        }
        previews.play(URL(filePath: "/x.caf"), key: MusicLibraryViewModel.previewKey(.lateStudy))
        let wentIn = await library.add(.lateStudy)
        #expect(wentIn && added == [.lateStudy])
        #expect(previews.playingKey == nil && library.adding == nil)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(for: .milliseconds(20)) }
        #expect(condition())
    }
}
