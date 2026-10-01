//
//  QuickEditCoverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Cover: a frame picked on the strip (the video shows it while the finger moves), a title in the
/// Cue preset, and Reset taking it away.
@MainActor
@Suite("Quick edit cover")
struct QuickEditCoverTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    @Test func aFramePickedOnTheStripBecomesTheCover() async {
        let (viewModel, player) = await makeViewModel()
        viewModel.panel = .cover
        viewModel.scrubCover(toEdited: 12)
        #expect(viewModel.isPickingCoverFrame)
        #expect(player.currentTime == 12)
        #expect(!viewModel.showsCoverImage)
        viewModel.endCoverScrub(atEdited: 12)
        #expect(viewModel.edit.cover?.source == .frame(12))
        #expect(viewModel.edit.cover?.preset == .cue)
        #expect(abs(viewModel.coverEditedTime - 12) < 0.001)
        #expect(viewModel.showsCoverImage)
    }

    @Test func aTitleMakesACoverFromThePlayhead() async {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 5)
        viewModel.setCoverTitle("5 comidas de SP")
        #expect(viewModel.edit.cover?.source == .frame(5))
        #expect(viewModel.edit.cover?.title == "5 comidas de SP")
        // In the Cue preset: black on a yellow box.
        #expect(viewModel.edit.cover?.titleOverlay?.background == .box)
        #expect(viewModel.edit.cover?.titleOverlay?.backgroundColor == .yellow)
        viewModel.removeCover()
        #expect(viewModel.edit.cover == nil)
    }

    @Test func coversMadeBeforeKeepTheirStyle() throws {
        let json = #"{"source":{"frame":{"_0":2}},"title":"Hi","titleY":0.2,"style":"bold"}"#
        let cover = try JSONDecoder().decode(VideoCover.self, from: Data(json.utf8))
        #expect(cover.preset == nil)
        #expect(cover.titleOverlay?.text == "Hi")
    }

    @Test func theStripSamplesTheEdit() async {
        let (viewModel, _) = await makeViewModel()
        let samples = viewModel.coverStripSamples(count: 4)
        #expect(samples.count == 4)
        #expect(abs(samples[0].time - 8) < 0.001)
        #expect(abs(samples[3].time - 56) < 0.001)
        #expect(samples.allSatisfy { $0.url == viewModel.videoURL })
    }

    @Test func aCutsMarkOpensItsTransitions() async {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 20)
        viewModel.selectClipAtPlayhead()
        viewModel.splitClip()
        viewModel.selection = nil
        let second = viewModel.edit.timeline.segments[1].id
        viewModel.tapTimeline(.join(second))
        #expect(viewModel.panel == .transition)
        #expect(viewModel.selectedJoinID == second)
        viewModel.setTransition(.dissolve)
        #expect(viewModel.edit.timeline.segments[1].transitionIn == .dissolve)
        // Tapped again: let go.
        viewModel.tapTimeline(.join(second))
        #expect(viewModel.panel == nil)
        #expect(viewModel.selectedJoinID == nil)
    }
}
