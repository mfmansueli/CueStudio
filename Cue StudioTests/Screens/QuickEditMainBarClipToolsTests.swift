//
//  QuickEditMainBarClipToolsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The clip tools on the main bar, with nothing picked: Speed, Volume, Zoom and Stabilize keep the clip under the playhead as
/// theirs while they're open (picked by the panel, let go at ✓); Duplicate, Replace, Extract audio, Copy look and Paste look
/// pick it first and show its tools; Reverse and Freeze frame work on it; Reorder with one clip says why it can't. Never in
/// silence.
@MainActor
@Suite("Quick edit main bar clip tools")
struct QuickEditMainBarClipToolsTests {
    @MainActor
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
        /// The two clips of a take split at 10 s.
        var clips: [EditSegment] { viewModel.edit.timeline.segments }
    }

    private func makeScenario(splitAt split: TimeInterval? = 10) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 21.6
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 21.6
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        if let split {
            player.seek(to: split)
            viewModel.perform(.splitClip)
            viewModel.leaveToolbarContext()
        }
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    // MARK: - A panel keeps its clip

    @Test(arguments: [EditorPanel.speed, .volume, .zoom, .stabilize, .clipCrop, .clipAnimation])
    func aClipPanelFromTheMainBarKeepsTheClipUnderThePlayhead(panel: EditorPanel) async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let second = scenario.clips[1]
        scenario.player.seek(to: 15)
        viewModel.perform(.open(panel))
        #expect(viewModel.panel == panel)
        // Picked by the panel: outlined on the timeline, and the one the panel changes.
        #expect(viewModel.selection == .clip(second.id))
        #expect(viewModel.clipScope == "Clip 2 of 2")
        // The playhead moves onto the other clip: the panel's clip stays.
        scenario.player.seek(to: 3)
        #expect(viewModel.targetClip?.id == second.id)
        #expect(viewModel.clipScope == "Clip 2 of 2")
        // ✓: back to nothing picked, the main bar, and no Delete for that clip.
        viewModel.closePanel()
        #expect(viewModel.selection == nil)
        #expect(viewModel.toolbarContext == .main)
        #expect(!viewModel.toolbarItems.contains { $0.isPinned })
    }

    @Test func aChangeMadeInThePinnedPanelLandsOnItsClip() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let second = scenario.clips[1].id
        scenario.player.seek(to: 15)
        viewModel.perform(.open(.volume))
        scenario.player.seek(to: 3)
        viewModel.updateClip { $0.volume = 0.4 }
        #expect(viewModel.edit.timeline.segment(id: second)?.volume == 0.4)
        #expect(viewModel.edit.timeline.segments[0].volume == 1)
    }

    @Test func aClipPickedBeforeThePanelStaysPickedAfterIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = scenario.clips[0].id
        viewModel.selection = .clip(first)
        scenario.player.seek(to: 15)
        viewModel.perform(.open(.speed))
        #expect(viewModel.selection == .clip(first))
        viewModel.closePanel()
        #expect(viewModel.selection == .clip(first))
        #expect(viewModel.toolbarContext == .clip)
    }

    @Test func aClipPickedWhileThePanelIsOpenIsTheCreatorsAndStays() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = scenario.clips[0].id
        scenario.player.seek(to: 15)
        viewModel.perform(.open(.speed))
        // A deliberate pick of the other clip: Speed follows it, by the usual rules.
        viewModel.selection = .clip(first)
        #expect(viewModel.panel == .speed)
        #expect(viewModel.targetClip?.id == first)
        viewModel.closePanel()
        #expect(viewModel.selection == .clip(first))
    }

    @Test func pickingSomethingElseClosesThePinnedPanelByTheUsualRules() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.addText(.title))
        let text = try #require(viewModel.selection?.textID)
        viewModel.closePanel()
        viewModel.leaveToolbarContext()
        viewModel.perform(.open(.zoom))
        viewModel.selection = .text(text)
        #expect(viewModel.panel == nil)
        #expect(viewModel.selection == .text(text))
    }

    @Test func aWholeVideoPanelPicksNothing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        for tool in [EditorLookTool.adjust, .skin, .filters, .background] {
            viewModel.perform(.openLook(tool, wholeVideo: true))
            #expect(viewModel.selection == nil)
            #expect(!viewModel.look.lookScopeIsClip)
            viewModel.closePanel()
        }
    }

    @Test func withOneClipTheToolsEditTheWholeVideo() async {
        let scenario = await makeScenario(splitAt: nil)
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.speed))
        #expect(viewModel.selection == .clip(scenario.clips[0].id))
        #expect(viewModel.clipScope == "This clip")
        viewModel.closePanel()
        #expect(viewModel.selection == nil)
    }

    // MARK: - Actions that pick the clip first

    @Test func duplicateFromTheMainBarPicksTheClipUnderThePlayheadAndCopiesIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let second = scenario.clips[1].id
        scenario.player.seek(to: 15)
        viewModel.perform(.duplicateClip)
        let clips = scenario.clips
        #expect(clips.count == 3)
        #expect(clips[1].id == second)
        #expect(viewModel.selection == .clip(clips[2].id), "the copy is picked: its tools show")
        #expect(viewModel.toolbarContext == .clip)
        #expect(scenario.toast.message == "Clip 2 duplicated after it")
    }

    @Test func replaceFromTheMainBarAsksForAVideoForTheClipUnderThePlayhead() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = scenario.clips[0].id
        scenario.player.seek(to: 4)
        viewModel.perform(.replaceClip)
        #expect(viewModel.selection == .clip(first))
        #expect(viewModel.photoRequest?.purpose == .replaceClip(first))
    }

    @Test func copyAndPasteLookFromTheMainBarWorkOnTheClipUnderThePlayhead() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        // Nothing copied: Paste look says so and picks nothing.
        viewModel.perform(.pasteLook)
        #expect(scenario.toast.message == "Copy a clip's look first")
        #expect(viewModel.selection == nil)
        scenario.player.seek(to: 4)
        viewModel.perform(.copyLook)
        #expect(viewModel.selection == .clip(scenario.clips[0].id))
        #expect(viewModel.look.copiedLook != nil)
        viewModel.leaveToolbarContext()
        scenario.player.seek(to: 15)
        viewModel.perform(.pasteLook)
        #expect(viewModel.selection == .clip(scenario.clips[1].id))
        #expect(viewModel.look.showsPasteLook)
    }

    @Test func extractAudioFromTheMainBarPicksTheClipUnderThePlayhead() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 15)
        viewModel.perform(.extractAudio)
        #expect(viewModel.selection == .clip(scenario.clips[1].id))
    }

    @Test func reorderWithOneClipSaysWhy() async {
        let scenario = await makeScenario(splitAt: nil)
        let viewModel = scenario.viewModel
        #expect(viewModel.toolbarItems.first { $0.id == "reorder" }?.style == .dimmed)
        viewModel.perform(.reorderClips)
        #expect(viewModel.sheet == nil)
        #expect(scenario.toast.message == "Split or add a clip to reorder")
    }

    @Test func noClipActionOnTheMainBarDeletes() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(!viewModel.toolbarItems.contains { $0.action == .deleteClip })
        // Delete only ever reaches a picked clip.
        viewModel.perform(.deleteClip)
        #expect(scenario.clips.count == 2)
    }

    // MARK: - Skin

    @Test func skinKeepsItsFocusWhileAdjustIsOpen() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.openLook(.skin, wholeVideo: true))
        #expect(viewModel.look.lookTool == .skin)
        // Adjust takes its one-time scroll target; the focus stays.
        viewModel.look.adjustOpensOn = nil
        #expect(viewModel.look.lookTool == .skin)
        viewModel.closePanel()
        #expect(viewModel.look.lookTool == nil)
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        #expect(viewModel.look.lookTool == .adjust)
        viewModel.perform(.open(.filters))
        #expect(viewModel.look.lookTool == nil)
    }
}
