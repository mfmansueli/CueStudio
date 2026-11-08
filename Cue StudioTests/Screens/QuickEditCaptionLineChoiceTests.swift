//
//  QuickEditCaptionLineChoiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Place and Zoom on the bar of a caption picked on the main timeline (E4 D, canvas 2 §6): the dialog names the line and its
/// time before anything changes, and only that line changes, in one undo step.
@MainActor
struct QuickEditCaptionLineChoiceTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
    }

    private let first = CaptionCue(text: "first line here", start: 0, end: 2, origin: .manual)
    private let second = CaptionCue(text: "second line here", start: 2.5, end: 4.5, origin: .manual)
    private let third = CaptionCue(text: "third line here", start: 5, end: 7, origin: .manual)

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit {
            $0.captions = [first, second, third]
            $0.showsCaptions = true
            if $0.captionCollection == nil { $0.captionCollection = CaptionSettings() }
        }
        return Scenario(viewModel: viewModel, toast: toast)
    }

    @Test func aCaptionPickedOnTheTimelineOffersPlaceAndZoom() async {
        let viewModel = await makeScenario().viewModel
        viewModel.selection = .caption(second.id)
        let ids = viewModel.toolbarItems.map(\.id)
        #expect(ids.contains("placeCaption"))
        #expect(ids.contains("zoomCaption"))
    }

    @Test func placeNamesTheLineThenMovesOnlyIt() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.selection = .caption(second.id)
        viewModel.perform(.placeCaption)
        let choice = try #require(viewModel.captions.lineChoice)
        #expect(choice.kind == .place)
        let message = viewModel.captions.lineChoiceMessage(choice)
        #expect(message.contains("second line here"))
        #expect(message.contains(CaptionPlace.withAll.label))
        let steps = viewModel.document.history.past.count
        viewModel.captions.chooseLinePlace(.own(.top), for: choice)
        #expect(viewModel.captions.lineChoice == nil)
        #expect(viewModel.edit.captions.first { $0.id == second.id }?.lineStyle?.y == CaptionPosition.top.verticalFraction)
        #expect(viewModel.edit.captions.first { $0.id == first.id }?.lineStyle?.y == nil)
        #expect(viewModel.edit.captions.first { $0.id == third.id }?.lineStyle?.y == nil)
        #expect(viewModel.document.history.past.count == steps + 1)
        viewModel.undo()
        #expect(viewModel.edit.captions.first { $0.id == second.id }?.lineStyle?.y == nil)
    }

    @Test func zoomNamesTheLineThenZoomsOnlyItsPhrase() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.selection = .caption(third.id)
        viewModel.perform(.zoomCaption)
        let choice = try #require(viewModel.captions.lineChoice)
        #expect(choice.kind == .zoom)
        #expect(viewModel.captions.lineChoiceMessage(choice).contains(String(localized: "No zoom")))
        viewModel.captions.chooseLineZoom(.strong, for: choice)
        #expect(viewModel.edit.phraseZooms.count == 1)
        #expect(viewModel.captions.phraseZoom(onLine: third.id)?.strength == .strong)
        #expect(viewModel.captions.phraseZoom(onLine: second.id) == nil)
        viewModel.captions.askLineChoice(.zoom, for: third.id)
        let again = try #require(viewModel.captions.lineChoice)
        viewModel.captions.chooseLineZoom(nil, for: again)
        #expect(viewModel.edit.phraseZooms.isEmpty)
    }

    @Test func theTimelineMarksALineWithAZoom() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.captions.askLineChoice(.zoom, for: first.id)
        viewModel.captions.chooseLineZoom(.medium, for: try #require(viewModel.captions.lineChoice))
        let input = viewModel.timelineInput(heightClass: .regular)
        #expect(input.captions.first { $0.id == first.id }?.symbol == "plus.magnifyingglass")
        #expect(input.captions.first { $0.id == second.id }?.symbol == nil)
    }
}
