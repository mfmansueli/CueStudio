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
    /// `logbook`: the Logbook whose ideas Scripts shows at the end of its list (an empty one, never written, when the test has none).
    private func makeViewModel(
        scripts: [Script], folders: [String] = [], logbook: LogbookService? = nil
    ) -> (ScriptsViewModel, ScriptLibraryService, ToastService) {
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: scripts, folders: folders), now: { TestData.now })
        library.load()
        let toast = ToastService()
        let ideas = logbook ?? LogbookService(defaults: TestDefaults().defaults)
        return (ScriptsViewModel(library: library, toast: toast, logbook: ideas), library, toast)
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

    @Test func aTapOnARowPicksTheScriptAndASecondLetsItGo() {
        let a = TestData.script(title: "A"), b = TestData.script(title: "B")
        let (viewModel, _, _) = makeViewModel(scripts: [a, b])
        viewModel.toggleSelecting()
        viewModel.toggleSelection(of: a.id)
        viewModel.toggleSelection(of: b.id)
        #expect(viewModel.selection == [a.id, b.id])
        viewModel.toggleSelection(of: a.id)
        #expect(viewModel.selection == [b.id])
        viewModel.toggleSelecting()
        #expect(viewModel.selection.isEmpty, "Done lets every script go")
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

    @Test func deletingTheFolderOnShowShowsAllAndUndoBringsItBack() throws {
        let script = TestData.script(folder: "Ideas")
        let (viewModel, library, toast) = makeViewModel(scripts: [script], folders: ["Ideas"])
        viewModel.filter = .folder("Ideas")
        viewModel.deleteFolder("Ideas")
        #expect(viewModel.filter == .all)
        #expect(!viewModel.filters.contains(.folder("Ideas")))
        #expect(library.script(id: script.id) != nil, "the scripts stay")
        #expect(toast.message == "Folder deleted")
        try #require(toast.action).perform()
        #expect(library.folders == ["Ideas"])
        #expect(library.script(id: script.id)?.folder == "Ideas")
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

    // MARK: - The Logbook's ideas at the end of the list

    /// Picked with the scripts, the Logbook's ideas go with them, and one Undo brings back all of it.
    @Test func theSelectionDeletesScriptsAndIdeasTogetherWithOneUndo() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let logbook = LogbookService(defaults: defaults.defaults, now: { TestData.now })
        let idea = try #require(logbook.add("Cold showers: myth vs. what helped"))
        let kept = try #require(logbook.add("A week of 5 a.m. starts"))
        let script = TestData.script(title: "A")
        let (viewModel, library, toast) = makeViewModel(scripts: [script], logbook: logbook)
        viewModel.isSelecting = true
        viewModel.toggleSelection(of: script.id)
        viewModel.toggleSelection(of: idea.id)
        viewModel.deleteSelection()
        #expect(library.scripts.isEmpty)
        #expect(logbook.waiting.map(\.id) == [kept.id])
        #expect(toast.message == "2 deleted" && !viewModel.isSelecting)
        try #require(toast.action).perform()
        #expect(library.scripts.map(\.title) == ["A"])
        #expect(logbook.waiting.map(\.text) == ["A week of 5 a.m. starts", "Cold showers: myth vs. what helped"])
    }

    /// Folders and Duplicate are for scripts: with only ideas picked they do nothing, and the ideas never reach the library.
    @Test func foldersAndDuplicateTakeOnlyThePickedScripts() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let logbook = LogbookService(defaults: defaults.defaults, now: { TestData.now })
        let idea = try #require(logbook.add("Three things I stopped buying"))
        let script = TestData.script(title: "A")
        let (viewModel, library, _) = makeViewModel(scripts: [script], folders: ["Brand deals"], logbook: logbook)
        viewModel.isSelecting = true
        viewModel.toggleSelection(of: idea.id)
        #expect(viewModel.selectedScripts.isEmpty)
        viewModel.duplicateSelection()
        #expect(library.scripts.count == 1 && viewModel.isSelecting, "Nothing to duplicate: still selecting")
        viewModel.toggleSelection(of: script.id)
        #expect(viewModel.selectedScripts == [script.id])
        viewModel.moveSelection(to: "Brand deals")
        #expect(library.script(id: script.id)?.folder == "Brand deals")
        #expect(logbook.waiting.count == 1, "The idea is not moved, nor deleted")
    }

    /// Held away from the end of the list: the idea goes, with Undo for 4 s, as a script does.
    @Test func anIdeaDeletedFromTheListCanBeUndone() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let logbook = LogbookService(defaults: defaults.defaults, now: { TestData.now })
        let idea = try #require(logbook.add("Packing hacks for surprise road trips"))
        let (viewModel, _, toast) = makeViewModel(scripts: [], logbook: logbook)
        viewModel.delete(idea)
        #expect(logbook.waiting.isEmpty && toast.message == "Idea deleted")
        try #require(toast.action).perform()
        #expect(logbook.waiting.map(\.id) == [idea.id])
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
