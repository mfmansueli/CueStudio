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
        let near = QuickEditViewModel.snapped(OverlayPoint(x: 0.51, y: 0.48))
        #expect(near.center == OverlayPoint(x: 0.5, y: 0.5))
        #expect(near.vertical && near.horizontal)
        let far = QuickEditViewModel.snapped(OverlayPoint(x: 0.6, y: 0.3))
        #expect(far.center == OverlayPoint(x: 0.6, y: 0.3))
        #expect(!far.vertical && !far.horizontal)
    }

    @Test func captionsStickToTopMiddleAndBottom() {
        #expect(QuickEditViewModel.snappedCaption(0.18).y == 0.16)
        #expect(QuickEditViewModel.snappedCaption(0.52).stop == 0.5)
        #expect(QuickEditViewModel.snappedCaption(0.74).y == 0.76)
        #expect(QuickEditViewModel.snappedCaption(0.62).stop == nil)
        #expect(QuickEditViewModel.snappedCaption(0.99).y == 0.9)
    }

    @Test func tappingATextPicksItThenOpensTextStyle() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.addText(.title))
        let id = try #require(viewModel.selectedTextID)
        viewModel.closePanel()
        viewModel.selection = nil
        viewModel.tapText(id)
        #expect(viewModel.selection == .text(id))
        #expect(viewModel.panel == nil)
        viewModel.tapText(id)
        #expect(viewModel.panel == .textStyle)
    }

    @Test func draggingCaptionsMovesThemAllInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.edit.captions = [CaptionCue(text: "Oi", start: 1, end: 2, origin: .manual)]
        viewModel.edit.showsCaptions = true
        viewModel.moveCaptions(toY: 0.17)
        #expect(viewModel.captionY == 0.16)
        viewModel.undo()
        #expect(viewModel.captionY != 0.16)
    }

    @Test func theCornerHandleScalesTheText() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.addText(.title))
        let id = try #require(viewModel.selectedTextID)
        let before = try #require(viewModel.selectedText).size
        viewModel.scaleText(id, by: CGSize(width: 35, height: 35))
        let after = try #require(viewModel.selectedText).size
        #expect(abs(after - before * 1.5) < 0.001)
        #expect(QuickEditViewModel.scaleFactor(for: CGSize(width: -500, height: 0)) == 0.4)
    }

    @Test func aTextWithKeyframesMovesItsKeyframe() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 1)
        viewModel.perform(.addText(.title))
        let id = try #require(viewModel.selectedTextID)
        viewModel.toggleKeyframe()
        scenario.player.seek(to: 2)
        viewModel.moveText(id, to: OverlayPoint(x: 0.3, y: 0.7))
        let text = try #require(viewModel.selectedText)
        #expect(text.keyframes.count == 2)
        #expect(text.keyframes.last?.center == OverlayPoint(x: 0.3, y: 0.7))
    }

    @Test func theSafeAreaFitsInsideThePreview() async {
        let viewModel = await makeScenario().viewModel
        let area = viewModel.safeArea(in: CGSize(width: 200, height: 356))
        #expect(area.minX > 0 && area.maxX < 200)
        #expect(area.minY > 0 && area.maxY < 356)
    }
}
