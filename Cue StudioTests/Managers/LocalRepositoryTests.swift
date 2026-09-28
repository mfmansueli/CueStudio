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
    /// Inside a folder named like the real one ("Application Support"): paths with spaces must work.
    private func temporaryDirectory() -> URL {
        URL.temporaryDirectory
            .appending(path: "cue tests \(UUID().uuidString)/Application Support", directoryHint: .isDirectory)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
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
        #expect(exists(repository.videoURL(named: fileName)))
        #expect(!exists(source))

        let take = TestData.take(scriptID: UUID())
        try repository.saveTakes([take])
        #expect(try repository.loadTakes() == [take])

        try repository.deleteVideo(named: fileName)
        #expect(!exists(repository.videoURL(named: fileName)))
    }

    // MARK: - Relaunch

    @Test func scriptsSurviveARelaunch() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = ScriptLibraryService(repository: LocalScriptRepository(directory: directory))
        before.load()
        let script = before.create(title: "Kept", text: "Hook.", platform: .reels)

        let after = ScriptLibraryService(repository: LocalScriptRepository(directory: directory))
        after.load()
        #expect(after.scripts.map(\.id) == [script.id])

        _ = after.create(title: "Second", text: "Body.", platform: .reels)
        let again = ScriptLibraryService(repository: LocalScriptRepository(directory: directory))
        again.load()
        #expect(again.scripts.count == 2)
    }

    @Test func takesSurviveARelaunch() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recording = URL.temporaryDirectory.appending(path: "recording-\(UUID().uuidString).mov")
        try Data("video".utf8).write(to: recording)
        let before = TakeLibraryService(repository: LocalTakeRepository(directory: directory))
        before.load()
        let take = try before.addTake(fileAt: recording, duration: 12, script: TestData.script(), camera: CameraSettings())

        let after = TakeLibraryService(repository: LocalTakeRepository(directory: directory))
        after.load()
        #expect(after.takes.map(\.id) == [take.id])
    }
}
