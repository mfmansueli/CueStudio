//
//  QuickEditPreviewTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Quick edit preview")
struct QuickEditPreviewTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 21.6
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 21.6
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player)
    }

    @Test func aTextSticksToTheMiddle() {
        let near = OverlaysViewModel.snapped(OverlayPoint(x: 0.51, y: 0.48))
        #expect(near.center == OverlayPoint(x: 0.5, y: 0.5))
        #expect(near.vertical && near.horizontal)
        let far = OverlaysViewModel.snapped(OverlayPoint(x: 0.6, y: 0.3))
        #expect(far.center == OverlayPoint(x: 0.6, y: 0.3))
        #expect(!far.vertical && !far.horizontal)
    }

    @Test func captionsStickToTopMiddleAndBottom() {
        #expect(CaptionsViewModel.snappedCaption(0.18).y == 0.16)
        #expect(CaptionsViewModel.snappedCaption(0.52).stop == 0.5)
        #expect(CaptionsViewModel.snappedCaption(0.74).y == 0.76)
        #expect(CaptionsViewModel.snappedCaption(0.62).stop == nil)
        #expect(CaptionsViewModel.snappedCaption(0.99).y == 0.9)
        // The stops are where Position puts the captions: a drag and the control agree.
        #expect(CaptionsViewModel.captionStops == CaptionPosition.allCases.map(\.verticalFraction))
        #expect(CaptionPosition.middle.verticalFraction == 0.5)
    }

    @Test func tappingATextPicksItThenOpensItsWordsToEdit() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.addText(.title))
        let id = try #require(viewModel.selectedTextID)
        viewModel.closePanel()
        viewModel.selection = nil
        viewModel.overlays.tapText(id)
        #expect(viewModel.selection == .text(id))
        #expect(viewModel.panel == nil)
        viewModel.overlays.focusesTextField = false
        viewModel.overlays.tapText(id)
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.overlays.focusesTextField)
    }

    @Test func tappingACaptionTwiceOpensItsLineWithTheKeyboard() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let cue = CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)
        viewModel.changeEdit {
            $0.captions = [cue]
            $0.showsCaptions = true
        }
        viewModel.captions.tapCaption(cue.id)
        #expect(viewModel.selection == .caption(cue.id))
        #expect(viewModel.panel == nil)
        viewModel.captions.tapCaption(cue.id)
        #expect(viewModel.panel == .captions)
        #expect(viewModel.captions.focusesCaptionField)
    }

    @Test func draggingCaptionsMovesThemAllInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.changeEdit {
            $0.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)]
            $0.showsCaptions = true
        }
        viewModel.captions.moveCaptions(toY: 0.17)
        #expect(viewModel.captions.captionY == 0.16)
        viewModel.undo()
        #expect(viewModel.captions.captionY != 0.16)
    }

    @Test func theCornerHandleScalesTheText() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.addText(.title))
        let id = try #require(viewModel.selectedTextID)
        let before = try #require(viewModel.selectedText).size
        viewModel.overlays.scaleText(id, by: CGSize(width: 35, height: 35))
        let after = try #require(viewModel.selectedText).size
        #expect(abs(after - before * 1.5) < 0.001)
        #expect(OverlaysViewModel.scaleFactor(for: CGSize(width: -500, height: 0)) == 0.4)
    }

    @Test func aTextWithKeyframesMovesItsKeyframe() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 1)
        viewModel.perform(.addText(.title))
        let id = try #require(viewModel.selectedTextID)
        viewModel.overlays.toggleKeyframe()
        scenario.player.seek(to: 2)
        viewModel.overlays.moveText(id, to: OverlayPoint(x: 0.3, y: 0.7))
        let text = try #require(viewModel.selectedText)
        #expect(text.keyframes.count == 2)
        #expect(text.keyframes.last?.center == OverlayPoint(x: 0.3, y: 0.7))
    }

    @Test func theSafeAreaFitsInsideThePreview() async {
        let viewModel = await makeScenario().viewModel
        let area = viewModel.overlays.safeArea(in: CGSize(width: 200, height: 356))
        #expect(area.minX > 0 && area.maxX < 200)
        #expect(area.minY > 0 && area.maxY < 356)
    }
}
