//
//  ScriptsViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("ScriptsViewModel")
struct ScriptsViewModelTests {
    private func makeViewModel(scripts: [Script], folders: [String] = []) -> (ScriptsViewModel, ScriptLibraryService, ToastService) {
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: scripts, folders: folders), now: { TestData.now })
        library.load()
        let toast = ToastService()
        return (ScriptsViewModel(library: library, toast: toast), library, toast)
    }

    @Test func filtersIncludeFolders() {
        let (viewModel, _, _) = makeViewModel(scripts: [], folders: ["Ideas"])
        #expect(viewModel.filters.last == .folder("Ideas"))
        #expect(viewModel.filters.first == .all)
    }

    @Test func deletingTheSelectionEndsSelecting() {
        let a = TestData.script(title: "A"), b = TestData.script(title: "B")
        let (viewModel, library, toast) = makeViewModel(scripts: [a, b])
        viewModel.isSelecting = true
        viewModel.selection = [a.id, b.id]
        viewModel.deleteSelection()
        #expect(library.scripts.isEmpty)
        #expect(!viewModel.isSelecting)
        #expect(viewModel.selection.isEmpty)
        #expect(toast.message == "2 deleted")
    }

    @Test func newFolderWithScriptsMovesThem() {
        let script = TestData.script()
        let (viewModel, library, toast) = makeViewModel(scripts: [script])
        viewModel.startNewFolder(moving: [script.id])
        viewModel.newFolderName = "Brand deals"
        viewModel.confirmNewFolder()
        #expect(library.script(id: script.id)?.folder == "Brand deals")
        #expect(toast.message == "Moved to “Brand deals”")
    }

    @Test func newEmptyFolderIsSelected() {
        let (viewModel, _, toast) = makeViewModel(scripts: [])
        viewModel.startNewFolder()
        viewModel.newFolderName = "Ideas"
        viewModel.confirmNewFolder()
        #expect(viewModel.filter == .folder("Ideas"))
        #expect(toast.message == "Folder created")
    }

    @Test func summaryCountsTheScriptsAndHowManyAreReady() {
        let recorded = TestData.script(title: "Recorded"), draft = TestData.script(title: "Draft", isFinished: false)
        let (viewModel, _, _) = makeViewModel(scripts: [TestData.script(title: "Ready"), draft, recorded])
        let counts = [recorded.id: 2]
        #expect(viewModel.summaryValues(takeCount: { counts[$0] ?? 0 }) == ["3 scripts", "1 ready"])
        #expect(makeViewModel(scripts: []).0.summaryValues(takeCount: { _ in 0 }).isEmpty)
    }

    @Test func theListIsGroupedReadyThenDraftsThenRecorded() {
        let ready = TestData.script(title: "Ready", updatedAt: TestData.now)
        let draft = TestData.script(title: "Draft", updatedAt: TestData.now.addingTimeInterval(-10), isFinished: false)
        let recorded = TestData.script(title: "Recorded", updatedAt: TestData.now.addingTimeInterval(-20))
        let moreReady = TestData.script(title: "More ready", updatedAt: TestData.now.addingTimeInterval(-30))
        let (viewModel, _, _) = makeViewModel(scripts: [recorded, draft, ready, moreReady])
        let groups = viewModel.groups(takeCount: { $0 == recorded.id ? 3 : 0 })
        #expect(groups.map(\.state) == [.ready, .draft, .recorded])
        #expect(groups[0].scripts.map(\.title) == ["Ready", "More ready"])
        #expect(groups[1].count == 1 && groups[2].count == 1)
    }

    @Test func aGroupWithNoScriptIsNotThere() {
        let (viewModel, _, _) = makeViewModel(scripts: [TestData.script()])
        #expect(viewModel.groups(takeCount: { _ in 0 }).map(\.state) == [.ready])
    }

    @Test func aFilterWithNoScriptsSaysWhy() {
        let (viewModel, _, _) = makeViewModel(scripts: [TestData.script(platform: .tiktok)], folders: ["Ideas"])
        #expect(viewModel.emptyResult == nil)
        viewModel.filter = .platform(.reels)
        #expect(viewModel.emptyResult == .platform(.reels))
        viewModel.filter = .folder("Ideas")
        #expect(viewModel.emptyResult == .folder("Ideas"))
        viewModel.filter = .all
        viewModel.query = "zzzz"
        #expect(viewModel.emptyResult == .search)
    }

    @Test func deletingAScriptCanBeUndoneForFourSeconds() throws {
        let script = TestData.script(title: "Keep me")
        let (viewModel, library, toast) = makeViewModel(scripts: [script])
        viewModel.delete(script)
        #expect(library.scripts.isEmpty)
        let undo = try #require(toast.action)
        #expect(toast.duration(for: nil, hasAction: true) == .seconds(4))
        undo.perform()
        #expect(library.scripts.map(\.title) == ["Keep me"])
        #expect(library.script(id: script.id)?.isFinished == script.isFinished)
    }

    @Test func deletingTheSelectionCanBeUndoneToo() throws {
        let a = TestData.script(title: "A", updatedAt: TestData.now), b = TestData.script(title: "B", updatedAt: TestData.now.addingTimeInterval(-5))
        let (viewModel, library, toast) = makeViewModel(scripts: [a, b])
        viewModel.selection = [a.id, b.id]
        viewModel.deleteSelection()
        try #require(toast.action).perform()
        #expect(library.scripts.map(\.title) == ["A", "B"])
    }

    @Test func eachFilterChipCountsItsScripts() {
        let (viewModel, _, _) = makeViewModel(scripts: [
            TestData.script(platform: .tiktok), TestData.script(platform: .tiktok), TestData.script(platform: .reels),
        ])
        #expect(viewModel.count(for: .all) == 3)
        #expect(viewModel.count(for: .platform(.tiktok)) == 2)
        #expect(viewModel.count(for: .platform(.reels)) == 1)
        #expect(viewModel.count(for: .platform(.shorts)) == 0)
    }

    /// The search is always there, so it narrows whatever platform is picked, and clearing it gives that platform's scripts back.
    @Test func theSearchAndThePlatformNarrowTheListTogether() {
        let lamp = TestData.script(title: "Lamp review", platform: .tiktok)
        let habits = TestData.script(title: "Morning habits", platform: .tiktok)
        let reel = TestData.script(title: "Lamp unboxing", platform: .reels)
        let (viewModel, _, _) = makeViewModel(scripts: [lamp, habits, reel])
        let titles = { Set(viewModel.groups(takeCount: { _ in 0 }).flatMap(\.scripts).map(\.title)) }
        viewModel.filter = .platform(.tiktok)
        viewModel.query = "lamp"
        #expect(titles() == ["Lamp review"])
        viewModel.query = ""
        #expect(titles() == ["Lamp review", "Morning habits"])
    }
}
