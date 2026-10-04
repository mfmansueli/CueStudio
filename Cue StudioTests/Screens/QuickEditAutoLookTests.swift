//
//  QuickEditAutoLookTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Adjust › Auto in Quick edit: measured on the clip in scope, applied as one undo step, with its
/// own intensity, reset and compare, and never applied to what was not picked when it started.
@MainActor
@Suite("Quick edit Auto")
struct QuickEditAutoLookTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario(editor: FakeTakeEditor = FakeTakeEditor()) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 21.6
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        editor.duration = 21.6
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor, player: player, toast: toast)
    }

    private func finish(_ viewModel: QuickEditViewModel) async {
        await viewModel.autoTask?.value
    }

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

    // MARK: - The take

    @Test func autoMeasuresTheTakeAndAppliesItAsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        #expect(viewModel.autoState == .analyzing)
        await finish(viewModel)
        #expect(viewModel.autoState == .idle)
        #expect(viewModel.edit.autoCorrection == FakeTakeEditor.measuredCorrection)
        #expect(viewModel.edit.autoAmount == 1 && viewModel.hasAuto)
        #expect(scenario.toast.message == "Auto applied · Adjust below")
        #expect(scenario.editor.autoSpans == [TimeSpan(start: 0, end: 21.6)])
        // The dials were not touched: Auto is a step of its own.
        #expect(viewModel.edit.exposure == 0 && viewModel.edit.contrast == 0 && viewModel.edit.saturation == 0)
        viewModel.undo()
        #expect(viewModel.edit.autoCorrection == nil)
        viewModel.redo()
        #expect(viewModel.edit.autoCorrection == FakeTakeEditor.measuredCorrection)
    }

    @Test func theIntensityChangesWithoutMeasuringAgain() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        await finish(viewModel)
        viewModel.setAutoAmount(40)
        #expect(viewModel.edit.autoAmount == 0.4 && viewModel.autoAmount == 0.4)
        viewModel.setAutoAmount(400)
        #expect(viewModel.edit.autoAmount == 1)
        #expect(scenario.editor.autoRequests == 1)
    }

    @Test func resetTakesAutoAwayAndKeepsTheDials() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.exposure, 20)
        viewModel.autoAdjust()
        await finish(viewModel)
        #expect(viewModel.canResetAuto)
        viewModel.resetAuto()
        #expect(viewModel.edit.autoCorrection == nil && !viewModel.canResetAuto)
        #expect(viewModel.edit.exposure == 20)
        viewModel.autoAdjust()
        await finish(viewModel)
        // Resetting everything takes Auto and the dials.
        viewModel.resetAdjustments()
        #expect(viewModel.edit.autoCorrection == nil && viewModel.edit.exposure == 0 && !viewModel.hasAdjustments)
    }

    @Test func aPictureThatLooksFineIsLeftAlone() async {
        let editor = FakeTakeEditor()
        editor.autoResult = AutoCorrection()
        let scenario = await makeScenario(editor: editor)
        scenario.viewModel.perform(.open(.adjust))
        scenario.viewModel.autoAdjust()
        await finish(scenario.viewModel)
        #expect(scenario.viewModel.edit.autoCorrection == nil)
        #expect(scenario.toast.message == "Already balanced")
    }

    @Test func ifMeasuringFailsThePictureStaysAndTheCreatorIsToldQuietly() async {
        let editor = FakeTakeEditor()
        editor.autoFails = true
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        await finish(viewModel)
        #expect(viewModel.edit.autoCorrection == nil && viewModel.autoState == .idle)
        #expect(scenario.toast.message == "Couldn’t measure · No change")
        editor.autoFails = false
        editor.autoResult = nil
        viewModel.autoAdjust()
        await finish(viewModel)
        #expect(viewModel.edit.autoCorrection == nil)
    }

    // MARK: - A clip

    @Test func openedFromAClipItMeasuresThatClipAndChangesOnlyIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        await finish(viewModel)
        #expect(scenario.editor.autoSpans == [TimeSpan(start: 7.1, end: 10.1)])
        #expect(viewModel.edit.autoCorrection == nil)
        #expect(viewModel.edit.timeline.segments[1].look?.auto == FakeTakeEditor.measuredCorrection)
        #expect(viewModel.edit.timeline.segments[0].look == nil && viewModel.edit.timeline.segments[2].look == nil)
        // Its own intensity, and Reset gives it the take's again.
        viewModel.setAutoAmount(30)
        #expect(viewModel.edit.timeline.segments[1].look?.autoAmount == 0.3)
        #expect(viewModel.canResetAuto)
        viewModel.resetAuto()
        #expect(viewModel.edit.timeline.segments[1].look == nil)
    }

    @Test func aClipCanTurnTheTakesAutoDown() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        await finish(viewModel)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.hasAuto && !viewModel.clipOverridesAuto)
        viewModel.setAutoAmount(0)
        #expect(viewModel.clipOverridesAuto && viewModel.autoAmount == 0)
        #expect(viewModel.edit.autoAmount == 1)
        #expect(viewModel.edit.timeline.segments[2].look?.autoAmount == 0)
    }

    // MARK: - Late results

    @Test func aResultThatArrivesAfterTheClipChangedIsDropped() async {
        let editor = FakeTakeEditor()
        editor.autoDelay = .milliseconds(150)
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        // Another clip is picked while measuring: the panel follows it, and what was measured for the first isn't its.
        pick(viewModel, clip: 0)
        await finish(viewModel)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.look == nil })
        #expect(viewModel.edit.autoCorrection == nil)
        #expect(viewModel.autoState == .idle)
    }

    @Test func closingThePanelStopsMeasuring() async {
        let editor = FakeTakeEditor()
        editor.autoDelay = .milliseconds(150)
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        viewModel.panel = nil
        #expect(viewModel.autoState == .idle)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.edit.autoCorrection == nil)
    }

    @Test func measuringTwiceAtOnceMeasuresOnce() async {
        let editor = FakeTakeEditor()
        editor.autoDelay = .milliseconds(100)
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.autoAdjust()
        viewModel.autoAdjust()
        await finish(viewModel)
        #expect(editor.autoRequests == 1)
    }

    // MARK: - Compare

    @Test func compareShowsThePictureAsRecordedUntilSomethingChanges() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        // Nothing to compare with yet.
        viewModel.togglePictureComparison()
        #expect(!viewModel.comparesPicture)
        viewModel.setAdjustment(.exposure, 30)
        viewModel.togglePictureComparison()
        #expect(viewModel.comparesPicture)
        #expect(scenario.player.shown.last?.exposure == 0)
        // What is saved never loses the look.
        #expect(viewModel.edit.exposure == 30)
        viewModel.togglePictureComparison()
        #expect(!viewModel.comparesPicture && scenario.player.shown.last?.exposure == 30)
        viewModel.togglePictureComparison()
        viewModel.setAdjustment(.contrast, 10)
        #expect(!viewModel.comparesPicture)
        viewModel.togglePictureComparison()
        viewModel.panel = nil
        #expect(!viewModel.comparesPicture)
    }

    // MARK: - Filters start balanced

    @Test func aFilterStartsAtItsOwnIntensityAndKeepsWhatTheCreatorSets() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.cinema)
        #expect(viewModel.edit.filter == .cinema && viewModel.edit.filterAmount == VideoFilter.cinema.defaultAmount)
        viewModel.setFilterAmount(0.3)
        viewModel.pickFilter(.cinema)
        #expect(viewModel.edit.filterAmount == 0.3)
        viewModel.pickFilter(.studio)
        #expect(viewModel.edit.filterAmount == VideoFilter.studio.defaultAmount)
        // The first filters start at full strength, as they always did.
        viewModel.pickFilter(.vivid)
        #expect(viewModel.edit.filterAmount == 1)
    }

    @Test func aClipsFilterStartsAtItsOwnIntensityToo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.retro)
        #expect(viewModel.edit.timeline.segments[1].look?.filter == .retro)
        #expect(viewModel.edit.timeline.segments[1].look?.filterAmount == VideoFilter.retro.defaultAmount)
        #expect(viewModel.edit.filter == .original)
        // The thumbnails come from the clip.
        #expect(viewModel.filterPreviewSource.time > 7.1 && viewModel.filterPreviewSource.time < 10.1)
    }
}
