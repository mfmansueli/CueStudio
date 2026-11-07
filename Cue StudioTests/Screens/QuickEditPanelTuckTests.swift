//
//  QuickEditPanelTuckTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Canvas 2 R10 §7.3: above Text style the timeline keeps the ruler and the texts' track alone; on the SE the styling sheet
/// steps aside for the whole timeline and comes back with the same text, tab and playhead; another panel brings it back out.
@MainActor
@Suite("Quick edit panel tuck")
struct QuickEditPanelTuckTests {
    private func makeViewModel() async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = SampleEdit.duration
        take.edit = SampleEdit.make(aspect: take.aspect)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = SampleEdit.duration
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func textStyleKeepsTheRulerAndTheTextsTrackAlone() async throws {
        let viewModel = await makeViewModel()
        let text = try #require(viewModel.edit.texts.first)
        viewModel.pick(.text(text.id))
        viewModel.panel = .textStyle
        let geometry = TimelineGeometry(viewModel.timelineInput(heightClass: .regular))
        #expect(geometry.lanes.map(\.lane) == [.text])
    }

    @Test func theSheetStepsAsideAndComesBackAsItWas() async throws {
        let viewModel = await makeViewModel()
        let text = try #require(viewModel.edit.texts.first)
        viewModel.pick(.text(text.id))
        viewModel.panel = .textStyle
        viewModel.panelTab = .font
        viewModel.player.seek(to: 3)
        viewModel.tuckPanel()
        #expect(viewModel.panelIsTucked && viewModel.panel == .textStyle)
        // The whole timeline, as with nothing open.
        let geometry = TimelineGeometry(viewModel.timelineInput(heightClass: .regular))
        #expect(geometry.lanes.contains { $0.lane == .main })
        viewModel.untuckPanel()
        #expect(!viewModel.panelIsTucked)
        #expect(viewModel.panel == .textStyle && viewModel.selection == .text(text.id) && viewModel.panelTab == .font)
        #expect(viewModel.player.currentTime == 3)
        // Another panel comes out in front.
        viewModel.tuckPanel()
        viewModel.panel = .captions
        #expect(!viewModel.panelIsTucked)
    }
}
