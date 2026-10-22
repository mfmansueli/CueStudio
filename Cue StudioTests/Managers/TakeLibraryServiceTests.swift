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

    @Test func cachedRecognitionSurvivesReopeningWithoutMarkingTheTakeEdited() throws {
        let take = TestData.take(scriptID: nil)
        let (service, repository) = makeService(takes: [take])
        let words = [CaptionWord(text: "Hello", start: 1, end: 2)]
        let transcript = CaptionTranscript(words: words, languageCode: "en")
        let lines = [CaptionCue(words: words)]
        service.cacheCaptions(lines, transcript: transcript, for: take.id)
        let reopened = TakeLibraryService(repository: repository)
        reopened.load()
        #expect(reopened.take(id: take.id)?.edit?.captionTranscript == transcript)
        #expect(reopened.take(id: take.id)?.edit?.captions == lines)
        #expect(reopened.take(id: take.id)?.isEdited == false)
        #expect(reopened.take(id: take.id)?.duration == take.duration)
        #expect(reopened.take(id: take.id)?.edit?.showsCaptions == false)
        #expect(reopened.take(id: take.id)?.edit?.voiceProcessing.isNeeded == false)
        #expect(reopened.take(id: take.id)?.edit?.captionCollection?.safeMargins == CaptionSafeArea.margins(for: take, aspect: take.aspect))
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

    @Test func aTakeTheLibraryCantWriteIsNotAddedAndItsVideoGoesBack() {
        let (service, repository) = makeService()
        repository.failsToSave = true
        var told = 0
        service.onTakeAdded = { _ in told += 1 }
        let clip = clipURL()
        #expect(throws: CocoaError.self) {
            try service.addTake(fileAt: clip, duration: 30, script: TestData.script(), camera: CameraSettings())
        }
        #expect(service.takes.isEmpty)
        #expect(repository.returnedFiles == [clip.lastPathComponent: clip])
        #expect(told == 0)
    }

    /// On disk: `takes.json` can't be written (a folder stands in its place), so the recording goes back to the camera's
    /// folder under its own name, where `TakeRecovery` looks at the next launch, and the library keeps no video without a take.
    @Test func aRecordingTheLibraryCantRecordIsLeftForTheNextLaunch() throws {
        let root = URL.temporaryDirectory.appending(path: "take-library-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = root.appending(path: "Takes", directoryHint: .isDirectory)
        let camera = root.appending(path: "Camera", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: camera, withIntermediateDirectories: true)
        let recording = camera.appending(path: "\(TakeRecovery.prefix)\(UUID().uuidString).mov")
        try Data("video".utf8).write(to: recording)
        let service = TakeLibraryService(repository: LocalTakeRepository(directory: library))
        service.load()
        try FileManager.default.createDirectory(at: library.appending(path: "takes.json"), withIntermediateDirectories: true)

        #expect(throws: (any Error).self) {
            try service.addTake(fileAt: recording, duration: 30, script: nil, camera: CameraSettings())
        }
        #expect(service.takes.isEmpty)
        #expect(FileManager.default.fileExists(atPath: recording.path(percentEncoded: false)))
        let stored = try FileManager.default.contentsOfDirectory(atPath: library.path(percentEncoded: false))
        #expect(stored == ["takes.json"])
        let leftovers = TakeRecovery.leftovers(files: EditStorageCleaner.modified(in: camera), launchedAt: .now.addingTimeInterval(1))
        #expect(leftovers == [recording.lastPathComponent])
    }

    @Test func anEditTheLibraryCantWriteSaysSoAndStaysInMemory() throws {
        let take = TestData.take(scriptID: nil)
        let (service, repository) = makeService(takes: [take])
        repository.failsToSave = true
        let edit = TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        #expect(throws: CocoaError.self) { try service.applyEdit(edit, to: take.id) }
        #expect(service.takes[0].isEdited)
        #expect(repository.takes[0].edit == nil)

        // The next save that works writes it.
        repository.failsToSave = false
        service.markExported(take.id)
        #expect(repository.takes[0].isEdited)
    }

    /// A take's draft goes with it, and the editor files only the draft named (added since the last Done): deleted at once,
    /// or once the Undo's seconds are over.
    @Test(arguments: [false, true])
    func deletingATakeTakesItsDraftAndWhatOnlyTheDraftNamed(withUndo: Bool) throws {
        let saved = try EditMediaFiles.newFile(pathExtension: "mov")
        let draftOnly = try EditMediaFiles.newFile(pathExtension: "mov")
        for file in [saved, draftOnly] { try Data([1]).write(to: file.url) }
        defer { EditMediaFiles.remove([saved.name, draftOnly.name]) }
        var take = TestData.take(scriptID: nil)
        var edit = TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        edit.sources = [ClipSource(fileName: saved.name, duration: 5, title: "B-roll")]
        take.edit = edit
        var drafted = edit
        drafted.sources.append(ClipSource(fileName: draftOnly.name, duration: 5, title: "New B-roll"))
        let drafts = FakeDraftStore()
        drafts.drafts[take.id] = QuickEditDraft(takeID: take.id, edit: drafted, playhead: 0, history: EditHistory(), savedAt: TestData.now)
        let service = TakeLibraryService(repository: FakeTakeRepository(takes: [take]), drafts: drafts)
        service.load()

        if withUndo {
            let removed = try #require(service.remove(take.id))
            #expect(drafts.drafts[take.id] != nil, "Undo can still bring it back")
            service.purge(removed)
        } else {
            service.delete(take.id)
        }
        #expect(drafts.drafts.isEmpty)
        #expect(!EditMediaFiles.exists(saved.name))
        #expect(!EditMediaFiles.exists(draftOnly.name))
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
