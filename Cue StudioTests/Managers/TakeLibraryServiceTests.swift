//
//  TakeLibraryServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("TakeLibraryService")
struct TakeLibraryServiceTests {
    private func makeService(takes: [Take] = []) -> (TakeLibraryService, FakeTakeRepository) {
        let repository = FakeTakeRepository(takes: takes)
        let service = TakeLibraryService(repository: repository, now: { TestData.now })
        service.load()
        return (service, repository)
    }

    private func clipURL() -> URL {
        URL.temporaryDirectory.appending(path: "clip-\(UUID().uuidString).mov")
    }

    @Test func takesAreNumberedPerScript() throws {
        let (service, _) = makeService()
        let script = TestData.script(version: 2)
        let first = try service.addTake(fileAt: clipURL(), duration: 30, script: script, camera: CameraSettings())
        let second = try service.addTake(fileAt: clipURL(), duration: 31, script: script, camera: CameraSettings())
        let freestyle = try service.addTake(fileAt: clipURL(), duration: 10, script: nil, camera: CameraSettings())
        #expect(first.number == 1)
        #expect(second.number == 2)
        #expect(second.scriptVersion == 2)
        #expect(freestyle.number == 1)
        #expect(freestyle.scriptTitle == "Freestyle recording")
        #expect(service.count(for: script.id) == 2)
    }

    @Test func takeRemembersTheCaptureSettings() throws {
        let (service, _) = makeService()
        var camera = CameraSettings()
        camera.aspect = .square
        camera.resolution = .uhd4K
        let take = try service.addTake(fileAt: clipURL(), duration: 30, script: nil, camera: camera)
        #expect(take.aspect == .square)
        #expect(take.resolution == .uhd4K)
    }

    @Test func onlyOneBestTakePerScript() {
        let scriptID = UUID()
        let a = TestData.take(scriptID: scriptID, number: 1)
        let b = TestData.take(scriptID: scriptID, number: 2, isBest: true)
        let other = TestData.take(scriptID: UUID(), number: 1, isBest: true)
        let (service, _) = makeService(takes: [a, b, other])
        service.setBest(a.id, isBest: true)
        #expect(service.take(id: a.id)?.isBest == true)
        #expect(service.take(id: b.id)?.isBest == false)
        #expect(service.take(id: other.id)?.isBest == true)
    }

    @Test func deleteRemovesTheVideoToo() {
        let take = TestData.take(scriptID: UUID())
        let (service, repository) = makeService(takes: [take])
        service.delete(take.id)
        #expect(service.takes.isEmpty)
        #expect(repository.deletedFiles == [take.fileName])
    }

    @Test func renamingAScriptUpdatesItsTakes() {
        let scriptID = UUID()
        let (service, _) = makeService(takes: [TestData.take(scriptID: scriptID, title: "Old")])
        service.renameScript(scriptID, to: "New")
        #expect(service.takes.first?.scriptTitle == "New")
    }

    @Test func siblingsAreTheScriptsTakesByNumber() {
        let script = UUID()
        let service = TakeLibraryService(repository: FakeTakeRepository(takes: [
            TestData.take(scriptID: script, number: 2),
            TestData.take(scriptID: nil, number: 1),
            TestData.take(scriptID: script, number: 1),
        ]))
        service.load()
        let take = service.takes.first { $0.scriptID == script && $0.number == 2 }!
        #expect(service.siblings(of: take).map(\.number) == [1, 2])
        let freestyle = service.takes.first { $0.scriptID == nil }!
        #expect(service.siblings(of: freestyle).map(\.id) == [freestyle.id])
    }

    @Test func freestyleBestTakesAreIndependent() {
        let service = TakeLibraryService(repository: FakeTakeRepository(takes: [
            TestData.take(scriptID: nil, number: 1, isBest: true),
            TestData.take(scriptID: nil, number: 2),
        ]))
        service.load()
        let second = service.takes.first { $0.number == 2 }!
        service.setBest(second.id, isBest: true)
        #expect(service.takes.filter(\.isBest).count == 2)
    }

    @Test func exportingMarksTheTakeShared() {
        let service = TakeLibraryService(repository: FakeTakeRepository(takes: [TestData.take(scriptID: UUID())]))
        service.load()
        let id = service.takes[0].id
        service.markExported(id)
        #expect(service.takes[0].isExported)
    }

    @Test func v1TakesOpenAsNotEditedAndNotShared() throws {
        let v1 = """
        [{"id":"00000000-0000-0000-0000-00000000000A","scriptTitle":"Old","number":1,"duration":30,
          "recordedAt":"2026-09-01T10:00:00Z","fileName":"a.mov","isBest":true,"resolution":"1080p",
          "frameRate":30,"aspect":"9:16","platform":"tiktok"}]
        """
        let takes = try JSONDecoder.library.decode([Take].self, from: Data(v1.utf8))
        #expect(takes[0].isBest)
        #expect(!takes[0].isEdited)
        #expect(!takes[0].isExported)
        #expect(takes[0].scriptID == nil)
    }
}
