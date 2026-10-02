//
//  QuickEditClipLookTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Adjust, Filters and Background opened from a picked clip change that clip only; from the main
/// toolbar they change the whole take, the base the clips play with.
@MainActor
@Suite("Quick edit clip looks")
struct QuickEditClipLookTests {
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

    // MARK: - Scope

    @Test func openedFromAClipAToolChangesThatClipOnly() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.lookClip?.id == viewModel.edit.timeline.segments[1].id)
        #expect(viewModel.panelSubtitle(.adjust) == "This clip · the rest stays as it is")
        viewModel.setAdjustment(.exposure, 40)
        #expect(viewModel.edit.exposure == 0)
        #expect(viewModel.edit.timeline.segments[1].look?.exposure == 40)
        #expect(viewModel.edit.timeline.segments[0].look == nil)
        #expect(viewModel.edit.timeline.segments[2].look == nil)
        #expect(viewModel.adjustment(.exposure) == 40)
    }

    @Test func openedFromTheMainToolbarChangesTheWholeTake() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.lookClip == nil)
        viewModel.setAdjustment(.exposure, 25)
        #expect(viewModel.edit.exposure == 25)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.look == nil })
        #expect(viewModel.panelSubtitle(.adjust) == "Whole take")
    }

    @Test func aClipShowsTheTakesValuesUntilItSetsItsOwn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.contrast, 30)
        viewModel.setAdjustment(.warmth, 10)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.adjustment(.contrast) == 30)
        #expect(!viewModel.clipOverrides(.contrast))
        viewModel.setAdjustment(.warmth, -20)
        #expect(viewModel.adjustment(.warmth) == -20)
        #expect(viewModel.adjustment(.contrast) == 30)
        #expect(viewModel.clipOverrides(.warmth) && !viewModel.clipOverrides(.contrast))
        // The take keeps its own.
        #expect(viewModel.edit.warmth == 10)
    }

    @Test func resetGivesTheClipTheTakesValuesAgain() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.exposure, 20)
        viewModel.panel = nil
        pick(viewModel, clip: 0)
        viewModel.perform(.open(.adjust))
        viewModel.setAdjustment(.exposure, -30)
        viewModel.setAdjustment(.shadows, 15)
        #expect(viewModel.hasAdjustments)
        viewModel.resetAdjustment(.exposure)
        #expect(viewModel.adjustment(.exposure) == 20)
        #expect(viewModel.edit.timeline.segments[0].look?.shadows == 15)
        viewModel.resetAdjustments()
        #expect(viewModel.edit.timeline.segments[0].look == nil)
        #expect(!viewModel.hasAdjustments)
    }

    @Test func aWholeTakeSubtitleSaysWhenSomeClipsKeepTheirOwn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.mono)
        viewModel.panel = nil
        viewModel.selection = nil
        viewModel.perform(.open(.filters))
        #expect(viewModel.panelSubtitle(.filters) == "Whole take · some clips keep their own")
        // Adjust has no clip of its own yet.
        #expect(viewModel.panelSubtitle(.adjust) == "Whole take")
    }

    // MARK: - Filters

    @Test func aClipsFilterOverridesTheTakesAndResetInheritsAgain() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.warm)
        viewModel.panel = nil
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        #expect(viewModel.currentFilter == .warm)
        #expect(!viewModel.clipOverridesFilter)
        viewModel.pickFilter(.mono)
        #expect(viewModel.currentFilter == .mono && viewModel.currentFilterAmount == 1)
        #expect(viewModel.edit.filter == .warm)
        viewModel.setFilterAmount(0.4)
        #expect(viewModel.edit.timeline.segments[1].look?.filterAmount == 0.4)
        #expect(viewModel.edit.filterAmount == 1)
        #expect(viewModel.clipOverridesFilter)
        viewModel.resetClipFilter()
        #expect(viewModel.currentFilter == .warm)
        #expect(viewModel.edit.timeline.segments[1].look == nil)
    }

    @Test func theClipsBadgeSaysWhatItChangesAndNothingWhenItInherits() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.warm)
        viewModel.panel = nil
        #expect(viewModel.timelineInput(heightClass: .regular).clips.allSatisfy { $0.badge == nil })
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.mono)
        viewModel.setAdjustment(.exposure, 10)
        let clips = viewModel.timelineInput(heightClass: .regular).clips
        #expect(clips[0].badge == nil && clips[2].badge == nil)
        #expect(clips[1].badge == "\(VideoFilter.mono.label) · Adjusted")
    }

    // MARK: - Following the picked clip

    @Test func aPanelOpenedFromAClipClosesWhenTheClipIsLetGoButTheTakesStays() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 0)
        viewModel.perform(.open(.filters))
        pick(viewModel, clip: 2)
        #expect(viewModel.panel == .filters)
        #expect(viewModel.lookClip?.id == viewModel.edit.timeline.segments[2].id)
        viewModel.selection = nil
        #expect(viewModel.panel == nil)
        #expect(!viewModel.lookScopeIsClip)
        viewModel.perform(.open(.filters))
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        #expect(viewModel.panel == .filters)
        #expect(viewModel.lookClip == nil)
    }

    // MARK: - Undo and splitting

    @Test func aClipsLookIsOneUndoStepAndSplittingKeepsIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 0)
        viewModel.perform(.open(.filters))
        viewModel.pickFilter(.mono)
        viewModel.panel = nil
        #expect(viewModel.edit.timeline.segments[0].look?.filter == .mono)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[0].look == nil)
        viewModel.redo()
        #expect(viewModel.edit.timeline.segments[0].look?.filter == .mono)
        scenario.player.seek(to: 3)
        pick(viewModel, clip: 0)
        viewModel.splitClip()
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 4)
        #expect(segments[0].look?.filter == .mono && segments[1].look?.filter == .mono)
        #expect(segments[2].look == nil && segments[3].look == nil)
    }

    // MARK: - Background

    @Test func aClipsBackgroundIsItsOwnAndGoesWhenItBecomesItsRecordings() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.background))
        viewModel.setBackgroundStyle(.blur)
        viewModel.panel = nil
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.background))
        #expect(viewModel.currentBackground.style == .blur)
        #expect(!viewModel.clipOverridesBackground)
        viewModel.setBackgroundStyle(.color)
        #expect(viewModel.edit.timeline.segments[1].look?.background?.style == .color)
        #expect(viewModel.edit.background(for: nil)?.style == .blur)
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[0])?.style == .blur)
        // Back to what its recording has: the clip inherits again.
        viewModel.setBackgroundStyle(.blur)
        #expect(viewModel.edit.timeline.segments[1].look == nil)
        viewModel.setBackgroundStyle(.color)
        viewModel.resetClipBackground()
        #expect(viewModel.edit.timeline.segments[1].look == nil)
    }

    @Test func aClipCanHaveNoBackgroundEffectWhileItsRecordingHasOne() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.background))
        viewModel.setBackgroundStyle(.blur)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.background))
        viewModel.setBackgroundStyle(.original)
        #expect(viewModel.clipOverridesBackground)
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[2]) == nil)
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[0])?.style == .blur)
    }

    @Test func theClipToolbarOffersTheVisualToolsInTheCurrentOrder() async {
        let scenario = await makeScenario()
        scenario.viewModel.perform(.selectClipAtPlayhead)
        let ids = scenario.viewModel.toolbarItems.map(\.id)
        #expect(ids == ["split", "speed", "adjust", "filters", "background", "zoom", "volume", "voice", "duplicate", "delete"])
    }
}
