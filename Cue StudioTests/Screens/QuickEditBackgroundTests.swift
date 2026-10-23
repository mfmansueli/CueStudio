//
//  QuickEditBackgroundTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Background in Quick edit: it belongs to the recording under the playhead, each change is an
/// undo step, and a photo from the library goes behind the creator.
@MainActor
@Suite("Quick edit background")
struct QuickEditBackgroundTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let importer: FakeMediaImporter
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let importer = FakeMediaImporter()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: importer, recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, importer: importer, toast: toast)
    }

    @Test func theTakesBackgroundIsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(viewModel.look.backgroundSourceID == nil)
        viewModel.look.setBackgroundStyle(.blur)
        #expect(viewModel.edit.background(for: nil)?.style == .blur)
        viewModel.beginChange()
        viewModel.look.updateBackground { $0.blur = 0.2 }
        viewModel.look.updateBackground { $0.blur = 0.9 }
        viewModel.endChange()
        #expect(viewModel.look.currentBackground.blur == 0.9)
        viewModel.undo()
        #expect(viewModel.look.currentBackground.blur == 0.5)
        viewModel.undo()
        #expect(viewModel.edit.background(for: nil) == nil)
    }

    @Test func anotherRecordingUnderThePlayheadGetsItsOwn() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let source = ClipSource(fileName: "walk.mov", duration: 10, title: "Walk")
        viewModel.changeEdit {
            $0.sources = [source]
            $0.timeline.insertClip(source: source.id, duration: 10)
        }
        scenario.player.currentTime = 70
        #expect(viewModel.look.backgroundSourceID == source.id)
        viewModel.look.setBackgroundCutout(.colorKey)
        viewModel.look.setBackgroundStyle(.color)
        #expect(viewModel.edit.background(for: source.id)?.cutout == .colorKey)
        #expect(viewModel.edit.background(for: nil) == nil)
    }

    @Test func aKeyColorKeepsItsTolerance() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.updateBackground { $0.key.tolerance = 0.6 }
        viewModel.look.setKeyColor(red: 0, green: 0.28, blue: 0.73)
        #expect(viewModel.look.currentBackground.key == {
            var key = ChromaKey.blue
            key.tolerance = 0.6
            return key
        }())
    }

    @Test func aPhotoGoesBehindTheCreator() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundImage("beach.jpg")
        #expect(viewModel.look.currentBackground.style == .image)
        #expect(viewModel.edit.background(for: nil)?.imageFileName == "beach.jpg")
        #expect(viewModel.importedFiles.contains("beach.jpg"))
    }

    @Test func aRecordingWithABackgroundShowsItOnItsClips() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(viewModel.timelineInput(heightClass: .regular).clips[0].badge == nil)
        viewModel.look.setBackgroundStyle(.blur)
        #expect(viewModel.timelineInput(heightClass: .regular).clips[0].badge == "Blur")
        // A photo style with no photo picked yet changes nothing, so the clip says nothing.
        viewModel.look.setBackgroundStyle(.image)
        #expect(viewModel.timelineInput(heightClass: .regular).clips[0].badge == nil)
        viewModel.look.setBackgroundImage("photo.jpg")
        #expect(viewModel.timelineInput(heightClass: .regular).clips[0].badge == "Image")
    }

    @Test func thePhotoLibraryIsAskedForByPurposeAndEachAskIsItsOwn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.requestPhoto(.background)
        let first = viewModel.photoRequest
        viewModel.requestPhoto(.background)
        #expect(viewModel.photoRequest?.purpose == .background)
        #expect(viewModel.photoRequest != first)
    }
}
