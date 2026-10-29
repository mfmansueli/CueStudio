//
//  EditMediaFilesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's media copies: a file from the app's bundle (a library track, a recorded effect) comes in linked or, where the
/// link is refused, copied; a file nothing names any more goes, and what was worked out from it (its motion analysis, a sound's
/// beats) goes with it.
@MainActor
@Suite("Edit media files")
struct EditMediaFilesTests {
    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test func aRemovedFileTakesWhatWasWorkedOutFromItWithIt() throws {
        let file = try EditMediaFiles.newFile(pathExtension: "mov")
        try Data([0]).write(to: file.url)
        let sidecars = [
            MotionAnalysisStore.url(forRecording: file.url),
            file.url.appendingPathExtension(BeatStore.pathExtension),
        ]
        for sidecar in sidecars { try Data([0]).write(to: sidecar) }

        EditMediaFiles.remove([file.name])
        #expect(!exists(file.url))
        #expect(sidecars.allSatisfy { !exists($0) })
    }

    /// A library track from the bundle comes into the edit's media whole, whether the system lets it be linked or not.
    @Test func aBundledTrackComesInLinkedOrCopied() throws {
        let track = try #require(CueTrack.quietHours.bundledFile)
        let original = try Data(contentsOf: track)
        let linked = try EditMediaFiles.link(track)
        defer { EditMediaFiles.remove([linked]) }
        #expect(try Data(contentsOf: EditMediaFiles.url(for: linked)) == original)
        #expect(linked.hasSuffix(".m4a"))
    }

    /// Where a hard link can't be made (from the bundle into the data container on a device, or across volumes), the file is
    /// copied instead.
    @Test func aRefusedLinkFallsBackToACopy() throws {
        let effect = try #require(SoundEffectFiles.bundled(.gong))
        var tried = false
        let name = try EditMediaFiles.link(effect) { _, _ in
            tried = true
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { EditMediaFiles.remove([name]) }
        #expect(tried)
        #expect(try Data(contentsOf: EditMediaFiles.url(for: name)) == Data(contentsOf: effect))
        let copy = try FileManager.default.attributesOfItem(atPath: EditMediaFiles.url(for: name).path(percentEncoded: false))
        #expect((copy[.referenceCount] as? Int) == 1, "a copy of its own, not a link")
    }

    /// A video copied in that can't be read leaves nothing behind: nothing would ever name it, so nothing would remove it.
    @Test func aVideoThatCantBeReadLeavesNoCopy() async throws {
        let file = try EditMediaFiles.newFile(pathExtension: "mov")
        try Data("not a movie".utf8).write(to: file.url)
        await #expect(throws: (any Error).self) { try await EditMediaImporter.describeVideo(at: file.url) }
        #expect(!exists(file.url))
    }
}
