//
//  ScriptLibraryServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("ScriptLibraryService")
struct ScriptLibraryServiceTests {
    private let now = TestData.now

    private func makeService(scripts: [Script] = [], folders: [String] = []) -> (ScriptLibraryService, FakeScriptRepository) {
        let repository = FakeScriptRepository(scripts: scripts, folders: folders)
        let service = ScriptLibraryService(repository: repository, now: { now })
        service.load()
        return (service, repository)
    }

    @Test func loadSortsByLastEdited() {
        let old = TestData.script(title: "Old", updatedAt: now.addingTimeInterval(-100))
        let new = TestData.script(title: "New", updatedAt: now)
        let (service, _) = makeService(scripts: [old, new])
        #expect(service.scripts.map(\.title) == ["New", "Old"])
        #expect(service.hasLoaded)
    }

    @Test func newScriptsStartInTheScriptLanguage() {
        let repository = FakeScriptRepository(scripts: [])
        let service = ScriptLibraryService(repository: repository, now: { now }, defaultLanguage: { .portugueseBrazil })
        service.load()
        #expect(service.create(title: "A", text: "Oi.", platform: .reels).language == .portugueseBrazil)
        #expect(service.create(title: "B", text: "Hola.", platform: .reels, language: .spanish).language == .spanish)
    }

    @Test func newScriptsAreAutoDetectByDefault() {
        let (service, _) = makeService()
        #expect(service.create(title: "A", text: "Hi.", platform: .reels).language == nil)
    }

    @Test func settingTheLanguageKeepsTheTextAndOrder() {
        let first = TestData.script(title: "First", text: "Bom dia, pessoal.", updatedAt: now)
        let second = TestData.script(title: "Second", updatedAt: now.addingTimeInterval(-100))
        let (service, repository) = makeService(scripts: [first, second])
        service.setLanguage(.portugueseBrazil, of: second.id)
        #expect(service.script(id: second.id)?.language == .portugueseBrazil)
        #expect(service.script(id: second.id)?.text == second.text)
        #expect(service.script(id: second.id)?.updatedAt == second.updatedAt)
        #expect(service.scripts.map(\.title) == ["First", "Second"])
        #expect(repository.saveCount == 1)
        service.setLanguage(nil, of: second.id)
        #expect(service.script(id: second.id)?.language == nil)
    }

    @Test func createPutsTheScriptOnTopAndSaves() {
        let (service, repository) = makeService(scripts: [TestData.script(title: "Existing")])
        let created = service.create(title: "Fresh", text: "Hi", platform: .reels, type: .review)
        #expect(service.scripts.first == created)
        #expect(created.createdAt == now)
        #expect(repository.snapshot.scripts.contains(created))
    }

    @Test func updateMovesTheScriptToTheTop() {
        let first = TestData.script(title: "First", updatedAt: now)
        let second = TestData.script(title: "Second", updatedAt: now.addingTimeInterval(-50))
        let (service, repository) = makeService(scripts: [first, second])
        service.update(second.id) { $0.text = "Changed" }
        #expect(service.scripts.map(\.title) == ["Second", "First"])
        #expect(service.scripts.first?.text == "Changed")
        #expect(repository.saveCount == 1)
    }

    @Test func duplicatesStartOverAtVersionOne() {
        let original = TestData.script(title: "Original", version: 3)
        let (service, _) = makeService(scripts: [original])
        let copies = service.duplicate([original.id])
        #expect(copies.count == 1)
        #expect(copies[0].title == "Original (copy)")
        #expect(copies[0].version == 1)
        #expect(copies[0].id != original.id)
        #expect(service.scripts.count == 2)
    }

    @Test func deleteRemovesScripts() {
        let script = TestData.script()
        let (service, repository) = makeService(scripts: [script])
        service.delete([script.id])
        #expect(service.scripts.isEmpty)
        #expect(repository.snapshot.scripts.isEmpty)
    }

    @Test func folderNamesAreUniqueAndNotEmpty() {
        let (service, _) = makeService(folders: ["Brand deals"])
        #expect(service.createFolder(named: "brand deals") == nil)
        #expect(service.createFolder(named: "   ") == nil)
        #expect(service.createFolder(named: " Ideas ") == "Ideas")
        #expect(service.folders == ["Brand deals", "Ideas"])
    }

    @Test func movingKeepsTheOrder() {
        let first = TestData.script(title: "First", updatedAt: now)
        let second = TestData.script(title: "Second", updatedAt: now.addingTimeInterval(-50))
        let (service, _) = makeService(scripts: [first, second])
        service.move([second.id], toFolder: "Ideas")
        #expect(service.scripts.map(\.title) == ["First", "Second"])
        #expect(service.script(id: second.id)?.folder == "Ideas")
    }

    @Test func deletingAFolderKeepsItsScripts() {
        let script = TestData.script(folder: "Ideas")
        let (service, _) = makeService(scripts: [script], folders: ["Ideas"])
        service.deleteFolder("Ideas")
        #expect(service.folders.isEmpty)
        #expect(service.script(id: script.id)?.folder == nil)
    }
}
