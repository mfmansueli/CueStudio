//
//  QuickEditCoverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's side of the cover: Cover Studio opens from the toolbar, the timeline and a notification; Done puts the cover in
/// the edit as one undo step, Cancel leaves it as it was, Remove cover takes it away.
@MainActor
@Suite("Quick edit cover")
struct QuickEditCoverTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback, FakeTextStyleStore) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let styles = FakeTextStyleStore()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: styles, coverPictures: FakeCoverPictures()
        )
        await viewModel.prepare()
        return (viewModel, player, styles)
    }

    @Test func theStudioOpensOnTheFrameUnderThePlayhead() async throws {
        let (viewModel, player, _) = await makeViewModel()
        player.seek(to: 12)
        viewModel.perform(.openCoverStudio)
        let studio = try #require(viewModel.cover.coverStudio)
        #expect(studio.step == .image)
        #expect(studio.cover.source.frame?.time == 12)
        #expect(studio.cover.composition != nil)
        // Nothing in the edit until Done.
        #expect(viewModel.edit.cover == nil)
    }

    @Test func doneIsOneUndoStepAndCancelKeepsTheCover() async throws {
        let (viewModel, _, _) = await makeViewModel()
        viewModel.cover.openCoverStudio()
        let studio = try #require(viewModel.cover.coverStudio)
        studio.setTitle("3 morning habits")
        studio.applyTemplate(.opinion)
        studio.addItem(.arrow)
        let steps = viewModel.document.history.past.count
        viewModel.cover.finishCoverStudio(studio)
        #expect(viewModel.cover.coverStudio == nil)
        #expect(viewModel.edit.cover?.title == "3 morning habits")
        #expect(viewModel.edit.cover?.composition?.template == .opinion)
        #expect(viewModel.document.history.past.count == steps + 1)

        viewModel.cover.openCoverStudio()
        let again = try #require(viewModel.cover.coverStudio)
        #expect(again.step == .text)
        again.setTitle("Something else")
        viewModel.cover.cancelCoverStudio(again)
        #expect(viewModel.edit.cover?.title == "3 morning habits")

        viewModel.undo()
        #expect(viewModel.edit.cover == nil)
    }

    @Test func removeCoverTakesItAway() async throws {
        let (viewModel, _, _) = await makeViewModel()
        viewModel.cover.openCoverStudio()
        viewModel.cover.finishCoverStudio(try #require(viewModel.cover.coverStudio))
        #expect(viewModel.edit.cover != nil)
        viewModel.cover.openCoverStudio()
        let studio = try #require(viewModel.cover.coverStudio)
        #expect(studio.hadCover)
        studio.removeCover()
        viewModel.cover.finishCoverStudio(studio)
        #expect(viewModel.edit.cover == nil)
    }

    @Test func aPhotoCopiedInIsCleanedUpWhenTheStudioIsCancelled() async throws {
        let (viewModel, _, _) = await makeViewModel()
        let file = try EditMediaFiles.newFile(pathExtension: "jpg")
        try Data([0]).write(to: file.url)
        defer { EditMediaFiles.remove([file.name]) }
        viewModel.cover.openCoverStudio()
        let studio = try #require(viewModel.cover.coverStudio)
        studio.remember(imported: file.name)
        studio.change { $0.source = .photo(fileName: file.name) }
        viewModel.cover.cancelCoverStudio(studio)
        #expect(!EditMediaFiles.exists(file.name))
    }

    @Test func theTimelineAndANotificationOpenTheStudio() async {
        let (viewModel, _, _) = await makeViewModel()
        viewModel.tapTimeline(.cover)
        #expect(viewModel.cover.coverStudio != nil)
        viewModel.cover.coverStudio = nil
        viewModel.open(.cover)
        #expect(viewModel.cover.coverStudio != nil)
    }

    @Test func aNewCoverStartsInMyStyle() async throws {
        let (viewModel, _, styles) = await makeViewModel()
        var saved = CoverComposition.make(.series, title: "x", episode: 2)
        saved.title.accent = .cyan
        styles.myCoverStyle = saved.style
        viewModel.cover.openCoverStudio()
        let studio = try #require(viewModel.cover.coverStudio)
        #expect(studio.composition.template == .series)
        #expect(studio.composition.title.accent == .cyan)
    }

    @Test func coversMadeBeforeOpenConvertedAndUntouchedUntilDone() async throws {
        let (viewModel, _, _) = await makeViewModel()
        var old = VideoCover(source: .frame(2))
        old.title = "Hi there"
        old.design = CoverDesign()
        viewModel.change { $0.cover = old }
        viewModel.cover.openCoverStudio()
        let studio = try #require(viewModel.cover.coverStudio)
        #expect(studio.cover.composition?.template == .opinion)
        viewModel.cover.cancelCoverStudio(studio)
        #expect(viewModel.edit.cover == old)
    }

    @Test func coversMadeBeforeKeepTheirStyle() throws {
        let json = #"{"source":{"frame":{"_0":2}},"title":"Hi","titleY":0.2,"style":"bold"}"#
        let cover = try JSONDecoder().decode(VideoCover.self, from: Data(json.utf8))
        #expect(cover.preset == nil)
        #expect(cover.composition == nil)
        #expect(cover.titleOverlay?.text == "Hi")
    }

    @Test func aCutsMarkOpensItsTransitions() async {
        let (viewModel, player, _) = await makeViewModel()
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
        viewModel.tapTimeline(.join(second))
        #expect(viewModel.panel == nil)
        #expect(viewModel.selectedJoinID == nil)
    }
}
