//
//  QuickEditSkinSmoothingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Skin Smoothing in Adjust: a dial like the others (the whole take, or the picked clip alone), with its own Reset, in the undo history, held back by
/// Compare, and saved with the edit.
@MainActor
@Suite("Quick edit Skin Smoothing")
struct QuickEditSkinSmoothingTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let takes: TakeLibraryService
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
        return Scenario(viewModel: viewModel, player: player, takes: takes)
    }

    /// Three clips: 0–7.1, 7.1–10.1, 10.1–21.6.
    private func split(_ scenario: Scenario) {
        scenario.player.seek(to: 7.1)
        scenario.viewModel.selectClipAtPlayhead()
        scenario.viewModel.splitClip()
        scenario.player.seek(to: 10.1)
        scenario.viewModel.splitClip()
        scenario.viewModel.selection = nil
    }

    private func pick(_ viewModel: QuickEditViewModel, clip index: Int) {
        viewModel.selection = .clip(viewModel.edit.timeline.segments[index].id)
    }

    // MARK: - The dial

    @Test func isTheLastDialOfAdjustAndNeedsNoNegativeSide() {
        let dials = QuickEditViewModel.Adjustment.allCases
        #expect(dials.last == .skinSmoothing)
        #expect(dials.count == 10)
        #expect(QuickEditViewModel.Adjustment.skinSmoothing.label == "Skin Smoothing")
        #expect(!QuickEditViewModel.Adjustment.skinSmoothing.isBipolar)
        #expect(QuickEditViewModel.Adjustment.skinSmoothing.hint != nil)
        #expect(dials.filter { $0.hint != nil } == [.skinSmoothing], "only the new dial needs a spoken hint")
    }

    @Test func startsAtZeroAndChangesTheTake() async {
        let viewModel = (await makeScenario()).viewModel
        #expect(viewModel.adjustment(.skinSmoothing) == 0)
        #expect(!viewModel.hasAdjustments)
        viewModel.setAdjustment(.skinSmoothing, 35)
        #expect(viewModel.edit.skinSmoothing == 35)
        #expect(viewModel.adjustment(.skinSmoothing) == 35)
        #expect(viewModel.hasAdjustments && viewModel.canResetAdjustment(.skinSmoothing))
        #expect(viewModel.effectiveLook.skinSmoothing == 35)
    }

    @Test func staysBetweenZeroAndOneHundred() async {
        let viewModel = (await makeScenario()).viewModel
        viewModel.setAdjustment(.skinSmoothing, 250)
        #expect(viewModel.edit.skinSmoothing == 100)
        viewModel.setAdjustment(.skinSmoothing, -40)
        #expect(viewModel.edit.skinSmoothing == 0)
        viewModel.setAdjustment(.skinSmoothing, 33.6)
        #expect(viewModel.edit.skinSmoothing == 34)
    }

    @Test func doesNotTouchTheFiltersOrTheOtherDials() async {
        let viewModel = (await makeScenario()).viewModel
        viewModel.pickFilter(.studio)
        viewModel.setAdjustment(.exposure, 15)
        let amount = viewModel.currentFilterAmount
        viewModel.setAdjustment(.skinSmoothing, 60)
        #expect(viewModel.edit.filter == .studio && viewModel.currentFilterAmount == amount)
        #expect(viewModel.edit.exposure == 15)
        viewModel.pickFilter(.original)
        #expect(viewModel.edit.skinSmoothing == 60, "any filter, or none, with the same smoothing")
        viewModel.resetAdjustment(.skinSmoothing)
        #expect(viewModel.edit.exposure == 15)
    }

    // MARK: - Undo and Reset

    @Test func undoAndRedoTakeItBackAndForth() async {
        let viewModel = (await makeScenario()).viewModel
        viewModel.setAdjustment(.skinSmoothing, 45)
        #expect(viewModel.canUndo)
        viewModel.undo()
        #expect(viewModel.edit.skinSmoothing == 0)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.edit.skinSmoothing == 45)
    }

    @Test func resetPutsOneDialOrEveryDialBack() async {
        let viewModel = (await makeScenario()).viewModel
        viewModel.setAdjustment(.skinSmoothing, 45)
        viewModel.setAdjustment(.contrast, 20)
        viewModel.resetAdjustment(.skinSmoothing)
        #expect(viewModel.edit.skinSmoothing == 0 && viewModel.edit.contrast == 20)
        #expect(!viewModel.canResetAdjustment(.skinSmoothing))
        viewModel.setAdjustment(.skinSmoothing, 45)
        viewModel.resetAdjustments()
        #expect(viewModel.edit.skinSmoothing == 0 && viewModel.edit.contrast == 0)
        #expect(!viewModel.hasAdjustments)
    }

    @Test func isSavedWithTheEditWhenDone() async {
        let scenario = await makeScenario()
        scenario.viewModel.setAdjustment(.skinSmoothing, 25)
        scenario.viewModel.done()
        #expect(scenario.takes.takes[0].edit?.skinSmoothing == 25)
    }

    // MARK: - Compare

    @Test func compareShowsThePictureWithoutItAndGivesItBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setAdjustment(.skinSmoothing, 50)
        #expect(scenario.player.shown.last?.skinSmoothing == 50)
        viewModel.holdPictureComparison(true)
        #expect(scenario.player.shown.last?.skinSmoothing == 0)
        #expect(viewModel.edit.skinSmoothing == 50, "what is saved doesn't change")
        viewModel.holdPictureComparison(false)
        #expect(scenario.player.shown.last?.skinSmoothing == 50)
    }

    // MARK: - Clips

    @Test func openedFromAClipItChangesThatClipOnly() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.skinSmoothing, 50)
        #expect(viewModel.edit.skinSmoothing == 0)
        #expect(viewModel.edit.timeline.segments[1].look?.skinSmoothing == 50)
        #expect(viewModel.edit.timeline.segments[0].look == nil && viewModel.edit.timeline.segments[2].look == nil)
        #expect(viewModel.adjustment(.skinSmoothing) == 50 && viewModel.clipOverrides(.skinSmoothing))
        #expect(viewModel.edit.lookSettings(for: viewModel.edit.timeline.segments[1]).skinSmoothing == 50)
        #expect(viewModel.edit.lookSettings(for: viewModel.edit.timeline.segments[0]).skinSmoothing == 0)
    }

    @Test func aClipShowsTheTakesValueUntilItSetsItsOwnAndResetGivesItBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.skinSmoothing, 30)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.adjustment(.skinSmoothing) == 30 && !viewModel.clipOverrides(.skinSmoothing))
        viewModel.setAdjustment(.skinSmoothing, 0)
        #expect(viewModel.adjustment(.skinSmoothing) == 0 && viewModel.clipOverrides(.skinSmoothing), "a clip can turn it off")
        #expect(viewModel.edit.skinSmoothing == 30)
        viewModel.resetAdjustment(.skinSmoothing)
        #expect(viewModel.adjustment(.skinSmoothing) == 30)
        #expect(viewModel.edit.timeline.segments[2].look == nil)
    }

    @Test func aClipsSmoothingSurvivesCuttingIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.skinSmoothing, 40)
        viewModel.panel = nil
        scenario.player.seek(to: 15)
        viewModel.selectClipAtPlayhead()
        viewModel.splitClip()
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 4)
        #expect(segments[2].look?.skinSmoothing == 40 && segments[3].look?.skinSmoothing == 40)
        #expect(segments[0].look == nil && segments[1].look == nil)
    }

    @Test func undoGivesTheClipItsOldValueBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.skinSmoothing, 50)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[1].look == nil)
        viewModel.redo()
        #expect(viewModel.edit.timeline.segments[1].look?.skinSmoothing == 50)
    }
}
