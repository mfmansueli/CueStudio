//
//  QuickEditWorkTests.swift
//  Cue StudioTests
//

import Foundation
import PhotosUI
import SwiftUI
import Testing
@testable import Cue_Studio

/// Work the creator waits for: an import says how far it got over the preview, and Cancel (or leaving) stops it and leaves the
/// edit as it was, without an error to read.
@MainActor
@Suite("Quick edit: work with Cancel")
struct QuickEditWorkTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let importer: FakeMediaImporter
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let importer = FakeMediaImporter()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: toast,
            player: FakeEditPlayback(), mediaImporter: importer, recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, importer: importer, toast: toast)
    }

    @Test func anImportSaysHowFarItIsAndCancelLeavesTheEdit() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.importer.progressSteps = [0.1, 0.4]
        scenario.importer.waitsUntilCancelled = true
        let importing = Task { await viewModel.overlays.importMedia(PhotosPickerItem(itemIdentifier: "in-icloud")) }
        await Wait.until { viewModel.work?.fraction == 0.4 }
        #expect(viewModel.work?.label == "Importing · 40%")
        viewModel.cancelWork()
        await importing.value
        #expect(viewModel.work == nil)
        #expect(viewModel.edit.media.isEmpty)
        #expect(scenario.toast.message == nil)
        #expect(!viewModel.isImportingMedia)
    }

    @Test func anImportThatFinishesIsAddedAndThePillGoes() async {
        let scenario = await makeScenario()
        scenario.importer.progressSteps = [0.5, 1]
        await scenario.viewModel.overlays.importMedia(PhotosPickerItem(itemIdentifier: "on-the-iphone"))
        #expect(scenario.viewModel.edit.media.count == 1)
        #expect(scenario.viewModel.work == nil)
    }

    @Test func leavingStopsAnImport() async {
        let scenario = await makeScenario()
        scenario.importer.waitsUntilCancelled = true
        let importing = Task { await scenario.viewModel.overlays.importMedia(PhotosPickerItem(itemIdentifier: "in-icloud")) }
        await Wait.until { scenario.viewModel.work != nil }
        scenario.viewModel.cancel()
        await importing.value
        #expect(scenario.viewModel.edit.media.isEmpty)
        #expect(scenario.toast.message != "Can't add this file")
    }

    @Test func aReverseCancelledBeforeItStartsLeavesTheClip() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.selectClipAtPlayhead()
        let timeline = viewModel.edit.timeline
        viewModel.perform(.reverseClip)
        viewModel.work = EditorWork(kind: .reversing, job: .reverse)
        viewModel.cancelWork()
        await viewModel.jobs.finished(.reverse)
        for _ in 0..<20 { await Task.yield() }
        #expect(viewModel.edit.timeline == timeline)
        #expect(scenario.toast.message != "Can’t reverse this clip")
        #expect(viewModel.work == nil)
    }
}
