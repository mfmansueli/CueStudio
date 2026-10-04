//
//  ScriptFinishedTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("ScriptLibraryService · finished")
struct ScriptFinishedTests {
    private func makeService() -> (ScriptLibraryService, FakeScriptRepository) {
        let repository = FakeScriptRepository()
        let service = ScriptLibraryService(repository: repository, now: { TestData.now })
        return (service, repository)
    }

    @Test func aNewScriptWithTextIsFinishedByDefaultAndABlankOneIsNot() {
        let (service, _) = makeService()
        #expect(service.create(title: "A", text: "Words", platform: .tiktok).isFinished)
        #expect(!service.create(title: "", text: "", platform: .tiktok).isFinished)
    }

    @Test func createTakesTheExplicitState() {
        let (service, _) = makeService()
        #expect(!service.create(title: "A", text: "From a format: sections empty", platform: .tiktok, isFinished: false).isFinished)
    }

    @Test func setFinishedIsSavedAndIsNotAnEdit() {
        let (service, repository) = makeService()
        let older = service.create(title: "Older", text: "x", platform: .tiktok, isFinished: false)
        _ = service.create(title: "Newer", text: "y", platform: .tiktok)
        let saves = repository.saveCount
        service.setFinished(true, of: older.id)
        #expect(service.script(id: older.id)?.isFinished == true)
        #expect(service.scripts.map(\.title) == ["Newer", "Older"])
        #expect(service.script(id: older.id)?.version == 1)
        #expect(repository.saveCount == saves + 1)
        service.setFinished(true, of: older.id)
        #expect(repository.saveCount == saves + 1)
    }
}
