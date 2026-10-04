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

    @Test func summaryCountsScriptsAndTakesAsTwoPaddedNumbers() {
        let (viewModel, _, _) = makeViewModel(scripts: [TestData.script(), TestData.script()])
        #expect(viewModel.summaryValues(takeCount: 3) == ["02 scripts", "03 takes"])
        #expect(makeViewModel(scripts: []).0.summaryValues(takeCount: 0).isEmpty)
    }

    @Test func theMagnifierShowsTheSearchAndHidingItClearsTheQuery() {
        let (viewModel, _, _) = makeViewModel(scripts: [TestData.script()])
        viewModel.isSearching = true
        viewModel.query = "lamp"
        viewModel.isSearching = false
        #expect(viewModel.query.isEmpty)
    }
}
