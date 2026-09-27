//
//  LocalRepositoryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Local repositories")
struct LocalRepositoryTests {
    private func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: "cue-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func scriptsRoundTrip() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalScriptRepository(directory: directory)
        #expect(try repository.load() == ScriptLibrarySnapshot())
        let snapshot = ScriptLibrarySnapshot(scripts: [TestData.script(type: .ad)], folders: ["Ideas"])
        try repository.save(snapshot)
        #expect(try repository.load() == snapshot)
    }

    @Test func takesRoundTripAndStoreVideos() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalTakeRepository(directory: directory)
        let source = URL.temporaryDirectory.appending(path: "source-\(UUID().uuidString).mov")
        try Data("video".utf8).write(to: source)

        let fileName = try repository.storeVideo(from: source)
        #expect(FileManager.default.fileExists(atPath: repository.videoURL(named: fileName).path()))
        #expect(!FileManager.default.fileExists(atPath: source.path()))

        let take = TestData.take(scriptID: UUID())
        try repository.saveTakes([take])
        #expect(try repository.loadTakes() == [take])

        try repository.deleteVideo(named: fileName)
        #expect(!FileManager.default.fileExists(atPath: repository.videoURL(named: fileName).path()))
    }
}
