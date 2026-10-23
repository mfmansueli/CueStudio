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
        await viewModel.jobs.finished(.auto)
    }

    private func split(_ scenario: Scenario) {
        scenario.player.seek(to: 7.1)
        scenario.viewModel.clips.selectClipAtPlayhead()
        scenario.viewModel.clips.splitClip()
        scenario.player.seek(to: 10.1)
        scenario.viewModel.clips.splitClip()
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
        viewModel.look.autoAdjust()
        #expect(viewModel.look.autoState == .analyzing)
        await finish(viewModel)
        #expect(viewModel.look.autoState == .idle)
        #expect(viewModel.edit.autoCorrection == FakeTakeEditor.measuredCorrection)
        #expect(viewModel.edit.autoAmount == 1 && viewModel.look.hasAuto)
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
        viewModel.look.autoAdjust()
        await finish(viewModel)
        viewModel.look.setAutoAmount(40)
        #expect(viewModel.edit.autoAmount == 0.4 && viewModel.look.autoAmount == 0.4)
        viewModel.look.setAutoAmount(400)
        #expect(viewModel.edit.autoAmount == 1)
        #expect(scenario.editor.autoRequests == 1)
    }

    @Test func resetTakesAutoAwayAndKeepsTheDials() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.look.setAdjustment(.exposure, 20)
        viewModel.look.autoAdjust()
        await finish(viewModel)
        #expect(viewModel.look.canResetAuto)
        viewModel.look.resetAuto()
        #expect(viewModel.edit.autoCorrection == nil && !viewModel.look.canResetAuto)
        #expect(viewModel.edit.exposure == 20)
        viewModel.look.autoAdjust()
        await finish(viewModel)
        // Resetting everything takes Auto and the dials.
        viewModel.look.resetAdjustments()
        #expect(viewModel.edit.autoCorrection == nil && viewModel.edit.exposure == 0 && !viewModel.look.hasAdjustments)
    }

    @Test func aPictureThatLooksFineIsLeftAlone() async {
        let editor = FakeTakeEditor()
        editor.autoResult = AutoCorrection()
        let scenario = await makeScenario(editor: editor)
        scenario.viewModel.perform(.open(.adjust))
        scenario.viewModel.look.autoAdjust()
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
        viewModel.look.autoAdjust()
        await finish(viewModel)
        #expect(viewModel.edit.autoCorrection == nil && viewModel.look.autoState == .idle)
        #expect(scenario.toast.message == "Couldn’t measure · No change")
        editor.autoFails = false
        editor.autoResult = nil
        viewModel.look.autoAdjust()
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
        viewModel.look.autoAdjust()
        await finish(viewModel)
        #expect(scenario.editor.autoSpans == [TimeSpan(start: 7.1, end: 10.1)])
        #expect(viewModel.edit.autoCorrection == nil)
        #expect(viewModel.edit.timeline.segments[1].look?.auto == FakeTakeEditor.measuredCorrection)
        #expect(viewModel.edit.timeline.segments[0].look == nil && viewModel.edit.timeline.segments[2].look == nil)
        // Its own intensity, and Reset gives it the take's again.
        viewModel.look.setAutoAmount(30)
        #expect(viewModel.edit.timeline.segments[1].look?.autoAmount == 0.3)
        #expect(viewModel.look.canResetAuto)
        viewModel.look.resetAuto()
        #expect(viewModel.edit.timeline.segments[1].look == nil)
    }

    @Test func aClipCanTurnTheTakesAutoDown() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.look.autoAdjust()
        await finish(viewModel)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.look.hasAuto && !viewModel.look.clipOverridesAuto)
        viewModel.look.setAutoAmount(0)
        #expect(viewModel.look.clipOverridesAuto && viewModel.look.autoAmount == 0)
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
        viewModel.look.autoAdjust()
        // Another clip is picked while measuring: the panel follows it, and what was measured for the first isn't its.
        pick(viewModel, clip: 0)
        await finish(viewModel)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.look == nil })
        #expect(viewModel.edit.autoCorrection == nil)
        #expect(viewModel.look.autoState == .idle)
    }

    @Test func closingThePanelStopsMeasuring() async {
        let editor = FakeTakeEditor()
        editor.autoDelay = .milliseconds(150)
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.look.autoAdjust()
        viewModel.panel = nil
        #expect(viewModel.look.autoState == .idle)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.edit.autoCorrection == nil)
    }

    @Test func measuringTwiceAtOnceMeasuresOnce() async {
        let editor = FakeTakeEditor()
        editor.autoDelay = .milliseconds(100)
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        viewModel.look.autoAdjust()
        viewModel.look.autoAdjust()
        await finish(viewModel)
        #expect(editor.autoRequests == 1)
    }

    // MARK: - Compare

    @Test func compareShowsThePictureAsRecordedUntilSomethingChanges() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.adjust))
        // Nothing to compare with yet.
        viewModel.look.togglePictureComparison()
        #expect(!viewModel.look.comparesPicture)
        viewModel.look.setAdjustment(.exposure, 30)
        viewModel.look.togglePictureComparison()
        #expect(viewModel.look.comparesPicture)
        #expect(scenario.player.shown.last?.exposure == 0)
        // What is saved never loses the look.
        #expect(viewModel.edit.exposure == 30)
        viewModel.look.togglePictureComparison()
        #expect(!viewModel.look.comparesPicture && scenario.player.shown.last?.exposure == 30)
        viewModel.look.togglePictureComparison()
        viewModel.look.setAdjustment(.contrast, 10)
        #expect(!viewModel.look.comparesPicture)
        viewModel.look.togglePictureComparison()
        viewModel.panel = nil
        #expect(!viewModel.look.comparesPicture)
    }

    // MARK: - Filters start balanced

    @Test func aFilterStartsAtItsOwnIntensityAndKeepsWhatTheCreatorSets() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.cinema)
        #expect(viewModel.edit.filter == .cinema && viewModel.edit.filterAmount == VideoFilter.cinema.defaultAmount)
        viewModel.look.setFilterAmount(0.3)
        viewModel.look.pickFilter(.cinema)
        #expect(viewModel.edit.filterAmount == 0.3)
        viewModel.look.pickFilter(.studio)
        #expect(viewModel.edit.filterAmount == VideoFilter.studio.defaultAmount)
        // The first filters start at full strength, as they always did.
        viewModel.look.pickFilter(.vivid)
        #expect(viewModel.edit.filterAmount == 1)
    }

    @Test func aClipsFilterStartsAtItsOwnIntensityToo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.retro)
        #expect(viewModel.edit.timeline.segments[1].look?.filter == .retro)
        #expect(viewModel.edit.timeline.segments[1].look?.filterAmount == VideoFilter.retro.defaultAmount)
        #expect(viewModel.edit.filter == .original)
        // The thumbnails come from the clip.
        #expect(viewModel.look.filterPreviewSource.time > 7.1 && viewModel.look.filterPreviewSource.time < 10.1)
    }
}
