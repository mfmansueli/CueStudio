//
//  QuickEditFocusTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One thing picked at a time (a cut included) and one panel open, each changed by one transition: a cut opens its
/// Transition panel and closing the panel lets go of it; picking closes a panel that can't work on what's picked, without
/// ending the undo step a gesture has open; leaving a panel ends its own.
@MainActor
@Suite("Quick edit: what is picked and open")
struct QuickEditFocusTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
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
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player)
    }

    /// Two clips cut at 8 s; returns the id of the second, which names the cut.
    private func cut(_ scenario: Scenario) -> UUID {
        scenario.player.seek(to: 8)
        scenario.viewModel.clips.selectClipAtPlayhead()
        scenario.viewModel.clips.splitClip()
        scenario.viewModel.selection = nil
        return scenario.viewModel.edit.timeline.segments[1].id
    }

    @Test func aCutIsPickedWithItsTransitionPanel() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let join = cut(scenario)
        viewModel.toolMenu = .audio
        viewModel.pickJoin(join)
        #expect(viewModel.selection == .join(join))
        #expect(viewModel.selectedJoinID == join)
        #expect(viewModel.panel == .transition)
        #expect(viewModel.toolMenu == nil)
        // Its ✓ lets go of the cut.
        viewModel.panel = nil
        #expect(viewModel.selection == nil)
        // Letting go of the cut closes its panel; tapping the cut again does too.
        viewModel.pickJoin(join)
        viewModel.selection = nil
        #expect(viewModel.panel == nil)
        viewModel.pickJoin(join)
        viewModel.pickJoin(join)
        #expect(viewModel.panel == nil)
        #expect(viewModel.selectedJoinID == nil)
    }

    @Test func pickingSomethingElseClosesTransitionAndACutClosesOtherPanels() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let join = cut(scenario)
        let first = viewModel.edit.timeline.segments[0].id
        viewModel.pickJoin(join)
        viewModel.selection = .clip(first)
        #expect(viewModel.panel == nil)
        #expect(viewModel.selectedJoinID == nil)
        viewModel.panel = .speed
        viewModel.pickJoin(join)
        #expect(viewModel.panel == .transition)
        #expect(viewModel.selectedSegmentID == nil)
    }

    @Test func aCutTheEditNoLongerHasIsLetGo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let join = cut(scenario)
        viewModel.pickJoin(join)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(viewModel.selectedJoinID == nil)
        #expect(viewModel.panel == nil)
    }

    @Test func pickingDuringAGestureKeepsItsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.clips.selectClipAtPlayhead()
        viewModel.panel = .speed
        let before = viewModel.edit
        viewModel.beginChange()
        viewModel.changeEdit { $0.cropOffset = 0.3 }
        // Something else is picked meanwhile: Speed can't work on it and closes, the gesture's step goes on.
        viewModel.overlays.addText(.title)
        #expect(viewModel.panel != .speed)
        viewModel.changeEdit { $0.cropOffset = 0.6 }
        viewModel.endChange()
        #expect(viewModel.edit.cropOffset == 0.6)
        viewModel.undo()
        #expect(viewModel.edit.cropOffset == before.cropOffset)
        #expect(viewModel.edit.texts.isEmpty)
    }

    @Test func leavingAPanelEndsItsUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .adjust
        viewModel.beginChange()
        viewModel.changeEdit { $0.exposure = 20 }
        viewModel.panel = nil
        #expect(viewModel.canUndo)
        viewModel.changeEdit { $0.contrast = 10 }
        viewModel.undo()
        #expect(viewModel.edit.exposure == 20)
        #expect(viewModel.edit.contrast == 0)
    }
}
