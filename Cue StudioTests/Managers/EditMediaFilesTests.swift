//
//  EditMediaFilesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's media copies: a file nothing names any more goes, and what was worked out from it (its motion and eye analyses,
/// a sound's beats) goes with it.
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
            MotionAnalysisStore.url(forRecording: file.url), EyeContactAnalysisStore.url(forRecording: file.url),
            file.url.appendingPathExtension(BeatStore.pathExtension),
        ]
        for sidecar in sidecars { try Data([0]).write(to: sidecar) }

        EditMediaFiles.remove([file.name])
        #expect(!exists(file.url))
        #expect(sidecars.allSatisfy { !exists($0) })
    }
}
