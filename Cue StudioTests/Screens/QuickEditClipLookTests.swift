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
        scenario.viewModel.clips.selectClipAtPlayhead()
        scenario.viewModel.clips.splitClip()
        scenario.player.seek(to: 10.1)
        scenario.viewModel.clips.splitClip()
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
        #expect(viewModel.look.lookClip?.id == viewModel.edit.timeline.segments[1].id)
        #expect(viewModel.panelSubtitle(.adjust) == "Clip 2 of 3 · only this clip")
        viewModel.look.setAdjustment(.exposure, 40)
        #expect(viewModel.edit.exposure == 0)
        #expect(viewModel.edit.timeline.segments[1].look?.exposure == 40)
        #expect(viewModel.edit.timeline.segments[0].look == nil)
        #expect(viewModel.edit.timeline.segments[2].look == nil)
        #expect(viewModel.look.adjustment(.exposure) == 40)
    }

    @Test func openedFromTheMainToolbarChangesTheWholeTake() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.look.lookClip == nil)
        viewModel.look.setAdjustment(.exposure, 25)
        #expect(viewModel.edit.exposure == 25)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.look == nil })
        #expect(viewModel.panelSubtitle(.adjust) == "Whole video")
    }

    @Test func aClipShowsTheTakesValuesUntilItSetsItsOwn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.look.setAdjustment(.contrast, 30)
        viewModel.look.setAdjustment(.warmth, 10)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.adjust))
        #expect(viewModel.look.adjustment(.contrast) == 30)
        #expect(!viewModel.look.clipOverrides(.contrast))
        viewModel.look.setAdjustment(.warmth, -20)
        #expect(viewModel.look.adjustment(.warmth) == -20)
        #expect(viewModel.look.adjustment(.contrast) == 30)
        #expect(viewModel.look.clipOverrides(.warmth) && !viewModel.look.clipOverrides(.contrast))
        // The take keeps its own.
        #expect(viewModel.edit.warmth == 10)
    }

    @Test func resetTakesTheClipsAdjustOffWhateverTheTakeHas() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.adjust))
        viewModel.look.setAdjustment(.exposure, 20)
        viewModel.panel = nil
        pick(viewModel, clip: 0)
        viewModel.perform(.open(.adjust))
        viewModel.look.setAdjustment(.exposure, -30)
        viewModel.look.setAdjustment(.shadows, 15)
        #expect(viewModel.look.hasAdjustments)
        viewModel.look.resetAdjustment(.exposure)
        #expect(viewModel.look.adjustment(.exposure) == 0, "zero on the clip, though the take's is 20")
        #expect(viewModel.edit.timeline.segments[0].look?.exposure == 0)
        #expect(viewModel.edit.timeline.segments[0].look?.shadows == 15)
        viewModel.look.resetAdjustments()
        #expect(viewModel.edit.timeline.segments[0].look?.exposure == 0)
        #expect(viewModel.edit.timeline.segments[0].look?.shadows == nil, "the take's shadows are zero: nothing of its own")
        #expect(!viewModel.look.hasAdjustments)
        #expect(viewModel.edit.exposure == 20)
    }

    @Test func aWholeTakeSubtitleSaysWhenSomeClipsKeepTheirOwn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.mono)
        viewModel.panel = nil
        viewModel.selection = nil
        viewModel.perform(.open(.filters))
        // The header says the reach; the clips that keep their own say so under it, with "Use this on all".
        #expect(viewModel.panelSubtitle(.filters) == "Whole video")
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 1)
        // Adjust has no clip of its own yet.
        viewModel.perform(.open(.adjust))
        #expect(viewModel.panelSubtitle(.adjust) == "Whole video")
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 0)
    }

    // MARK: - Filters

    @Test func aClipsFilterOverridesTheTakesAndResetTakesItOff() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.warm)
        viewModel.panel = nil
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        #expect(viewModel.look.currentFilter == .warm)
        #expect(viewModel.edit.timeline.segments[1].look?.filter == nil)
        viewModel.look.pickFilter(.mono)
        #expect(viewModel.look.currentFilter == .mono && viewModel.look.currentFilterAmount == 1)
        #expect(viewModel.edit.filter == .warm)
        viewModel.look.setFilterAmount(0.4)
        #expect(viewModel.edit.timeline.segments[1].look?.filterAmount == 0.4)
        #expect(viewModel.edit.filterAmount == 1)
        #expect(viewModel.edit.timeline.segments[1].look?.filter == .mono)
        // Off the clip, whatever the whole video has: Original of its own.
        viewModel.look.resetFilter()
        #expect(viewModel.look.currentFilter == .original)
        #expect(viewModel.edit.timeline.segments[1].look?.filter == .original)
        #expect(viewModel.edit.timeline.segments[1].look?.filterAmount == nil)
        #expect(viewModel.edit.filter == .warm)
        #expect(!viewModel.look.hasFilterSettings)
    }

    /// Natural, then Studio: Filters' Reset is there on the whole video too, and takes its filter off in one step; on a clip it
    /// takes off the filter the clip shows, its own or the whole video's.
    @Test func filtersResetTakesTheWholeVideosFilterOffAndAClipsOwn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.filters))
        #expect(!viewModel.look.hasFilterSettings)
        viewModel.look.pickFilter(.natural)
        viewModel.look.pickFilter(.studio)
        viewModel.look.setFilterAmount(0.4)
        #expect(viewModel.look.hasFilterSettings)
        viewModel.look.resetFilter()
        #expect(viewModel.edit.filter == .original && viewModel.edit.filterAmount == 1)
        #expect(!viewModel.look.hasFilterSettings)
        viewModel.undo()
        #expect(viewModel.edit.filter == .studio && viewModel.edit.filterAmount == 0.4)
        viewModel.panel = nil
        split(scenario)
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        #expect(viewModel.look.hasFilterSettings, "the whole video's Studio shows on the clip, so Reset is there")
        viewModel.look.pickFilter(.natural)
        #expect(viewModel.look.hasFilterSettings)
        viewModel.look.resetFilter()
        #expect(viewModel.look.currentFilter == .original && viewModel.edit.filter == .studio)
        #expect(viewModel.edit.timeline.segments[1].look?.filter == .original)
        #expect(!viewModel.look.hasFilterSettings)
        // With no filter on the whole video, Reset on a clip just gives up the clip's own.
        viewModel.panel = nil
        viewModel.selection = nil
        viewModel.perform(.open(.filters))
        viewModel.look.resetFilter()
        viewModel.panel = nil
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.natural)
        viewModel.look.resetFilter()
        #expect(viewModel.edit.timeline.segments[1].look == nil)
    }

    @Test func theClipsBadgeSaysWhatItChangesAndNothingWhenItInherits() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.warm)
        viewModel.panel = nil
        #expect(viewModel.timelineInput(heightClass: .regular).clips.allSatisfy { $0.badge == nil })
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.mono)
        viewModel.look.setAdjustment(.exposure, 10)
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
        #expect(viewModel.look.lookClip?.id == viewModel.edit.timeline.segments[2].id)
        viewModel.selection = nil
        #expect(viewModel.panel == nil)
        #expect(!viewModel.look.lookScopeIsClip)
        viewModel.perform(.open(.filters))
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        #expect(viewModel.panel == .filters)
        #expect(viewModel.look.lookClip == nil)
    }

    // MARK: - Undo and splitting

    @Test func aClipsLookIsOneUndoStepAndSplittingKeepsIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        pick(viewModel, clip: 0)
        viewModel.perform(.open(.filters))
        viewModel.look.pickFilter(.mono)
        viewModel.panel = nil
        #expect(viewModel.edit.timeline.segments[0].look?.filter == .mono)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[0].look == nil)
        viewModel.redo()
        #expect(viewModel.edit.timeline.segments[0].look?.filter == .mono)
        scenario.player.seek(to: 3)
        pick(viewModel, clip: 0)
        viewModel.clips.splitClip()
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
        viewModel.look.setBackgroundStyle(.blur)
        viewModel.panel = nil
        pick(viewModel, clip: 1)
        viewModel.perform(.open(.background))
        #expect(viewModel.look.currentBackground.style == .blur)
        #expect(!viewModel.look.clipOverridesBackground)
        viewModel.look.setBackgroundStyle(.color)
        #expect(viewModel.edit.timeline.segments[1].look?.background?.style == .color)
        #expect(viewModel.edit.background(for: nil)?.style == .blur)
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[0])?.style == .blur)
        // Back to what its recording has: the clip inherits again.
        viewModel.look.setBackgroundStyle(.blur)
        #expect(viewModel.edit.timeline.segments[1].look == nil)
        // Reset: as recorded behind the creator, though its recording has a blur.
        viewModel.look.setBackgroundStyle(.color)
        #expect(viewModel.look.canResetClipBackground)
        viewModel.look.resetClipBackground()
        #expect(viewModel.edit.timeline.segments[1].look?.background == BackgroundEffect())
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[1]) == nil)
        #expect(!viewModel.look.canResetClipBackground)
    }

    @Test func aClipCanHaveNoBackgroundEffectWhileItsRecordingHasOne() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        viewModel.perform(.open(.background))
        viewModel.look.setBackgroundStyle(.blur)
        viewModel.panel = nil
        pick(viewModel, clip: 2)
        viewModel.perform(.open(.background))
        viewModel.look.setBackgroundStyle(.original)
        #expect(viewModel.look.clipOverridesBackground)
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[2]) == nil)
        #expect(viewModel.edit.background(for: viewModel.edit.timeline.segments[0])?.style == .blur)
    }

    @Test func theClipToolbarOffersTheVisualToolsInTheCurrentOrder() async {
        let scenario = await makeScenario()
        scenario.viewModel.perform(.selectClipAtPlayhead)
        let ids = scenario.viewModel.toolbarItems.map(\.id)
        #expect(ids == [
            "split", "speed", "volume", "mute", "zoom",
            "adjust", "skin", "filters", "background", "clipCrop", "mirror", "stabilize", "blurArea", "copyLook", "pasteLook",
            "transition", "clipAnimation", "duplicate", "freeze", "reverse", "replace", "reorder", "extractAudio", "voiceEffects", "resetClip",
            "text", "addMedia", "audio",
            "pauses", "autoEdit", "editByText", "voice", "captions", "format", "templates", "brandKit", "cover", "delete",
        ])
    }
}
