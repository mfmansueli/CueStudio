//
//  QuickEditCoverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Cover: a frame picked on the strip (the video shows it while the finger moves), a title in the
/// v26 design, and Reset taking it away.
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
        // A new cover is a v26 design: the Hook layout, in Anton, nothing on top.
        #expect(viewModel.edit.cover?.design?.layout == .hook)
        #expect(abs(viewModel.coverEditedTime - 12) < 0.001)
        #expect(viewModel.showsCoverImage)
    }

    @Test func aTitleMakesACoverFromThePlayhead() async {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 5)
        viewModel.setCoverTitle("5 comidas de SP")
        #expect(viewModel.edit.cover?.source == .frame(5))
        #expect(viewModel.edit.cover?.title == "5 comidas de SP")
        #expect(viewModel.edit.cover?.design?.font == .anton)
        viewModel.removeCover()
        #expect(viewModel.edit.cover == nil)
    }

    @Test func theDesignChangesAreUndoableSteps() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.setCoverLayout(.number)
        #expect(viewModel.edit.cover?.design?.layout == .number)
        viewModel.setCoverFont(.serif)
        viewModel.setCoverEffect(.dim)
        viewModel.toggleCoverElement(.badge)
        #expect(viewModel.edit.cover?.design?.elements == [.badge])
        viewModel.toggleCoverElement(.badge)
        #expect(viewModel.edit.cover?.design?.elements.isEmpty == true)
        viewModel.undo()
        #expect(viewModel.edit.cover?.design?.elements == [.badge])
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.cover?.design?.font == .serif)
    }

    @Test func theHandleElementCarriesTheCreatorsHandle() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.creatorHandle = "mayacooks"
        viewModel.toggleCoverElement(.handle)
        #expect(viewModel.edit.cover?.design?.handle == "mayacooks")
    }

    @Test func suggestionsCoverTheTitleAndPutTheHighlightOnTheSecondWord() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.useCoverSuggestion("3 morning habits")
        #expect(viewModel.edit.cover?.title == "3 morning habits")
        #expect(viewModel.edit.cover?.design?.highlightIndex == 1)
        viewModel.useCoverSuggestion("Wow")
        #expect(viewModel.edit.cover?.design?.highlightIndex == 0)
        #expect(viewModel.coverSuggestions.count <= 3)
    }

    @Test func myCoverStyleIsSavedAndStartsNewCovers() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.setCoverLayout(.kicker)
        viewModel.setCoverFont(.grotesk)
        viewModel.setCoverEffect(.blur)
        viewModel.toggleCoverElement(.series)
        viewModel.saveMyCoverStyle()
        #expect(viewModel.myCoverLook == CoverLook(layout: .kicker, font: .grotesk, effect: .blur, series: true))

        // A cover made after it starts in the style, with its own words.
        viewModel.removeCover()
        viewModel.setCoverTitle("Hello there")
        #expect(viewModel.edit.cover?.design?.layout == .kicker)
        #expect(viewModel.edit.cover?.design?.effect == .blur)
        #expect(viewModel.edit.cover?.design?.elements == [.series])

        // And it can be given to a cover that has another look.
        viewModel.setCoverLayout(.hook)
        viewModel.setCoverFont(.anton)
        viewModel.applyMyCoverStyle()
        #expect(viewModel.edit.cover?.design?.layout == .kicker && viewModel.edit.cover?.design?.font == .grotesk)
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
